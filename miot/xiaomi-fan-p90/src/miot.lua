local socket = require "socket"
local json = require "st.json"
local security = require "st.security"
local md5 = require "md5"

-- MIoT protocol module
local miot = {}

local PORT = 54321
local HEADER_SIZE = 32
local MAX_PROPERTIES_PER_REQUEST = 15
local DEV_ID = "dev_id"
local TIME_OFFSET = "time_offset"
local MESSAGE_ID = "message_id"
local HELLO_PACKET = "\x21\x31\x00\x20" .. string.rep("\xff", 28)
local AES_OPTIONS = { cipher = "aes128-cbc", padding = true }

-- Derive the encryption key and IV from the device token.
local function get_crypto_params(token)
    local token_bin = md5.hex_to_bin(token)
    local key = md5.sum(token_bin)
    local iv = md5.sum(key .. token_bin)
    return token_bin, key, iv
end

-- Create a UDP socket for the miIO LAN protocol.
local function create_udp()
    local udp = socket.udp()
    if not udp then error("Unable to create UDP socket") end
    udp:setsockname("0.0.0.0", 0)
    udp:settimeout(5)
    return udp
end

-- Reset cached handshake state after a transport failure.
local function clear_device_cache(device)
    device:set_field(DEV_ID, nil)
    device:set_field(TIME_OFFSET, nil)
end

local function next_message_id(device)
    local message_id = ((device:get_field(MESSAGE_ID) or 0) % 9999) + 1
    device:set_field(MESSAGE_ID, message_id)
    return message_id
end

local function assert_success(response)
    local result = response and response.result and response.result[1]
    if not result or result.code ~= 0 then
        local code = result and result.code or "nil"
        error("MIoT command failed: " .. tostring(code))
    end
    return response
end

-- Send the miIO hello packet to obtain the device id and clock offset.
local function send_hello(ip)
    local udp = create_udp()

    udp:sendto(HELLO_PACKET, ip, PORT)

    local response = udp:receive()
    udp:close()

    if not response then error("No response from device") end

    -- Extract the device id and timestamp as big-endian 32-bit integers.
    local device_id = string.unpack(">I4", response:sub(9, 12))
    local device_time = string.unpack(">I4", response:sub(13, 16))
    local time_offset = os.time() - device_time

    return device_id, time_offset
end

-- Construct an encrypted MIoT request and return reusable crypto parameters.
local function create_message(device, ip, token, method, params, force_hello)
    -- Refresh the handshake state when it is missing or invalidated.
    if device:get_field(DEV_ID) == nil or force_hello then
        local ok, dev_id, time_off = pcall(send_hello, ip)
        if not ok then
            clear_device_cache(device)
            error("Hello request failed: " .. tostring(dev_id))
        end
        device:set_field(DEV_ID, dev_id)
        device:set_field(TIME_OFFSET, time_off)
    end

    -- Build the JSON payload before encryption.
    local payload = json.encode({
        id = next_message_id(device),
        method = method,
        params = params or {}
    }) .. '\x00'

    -- Derive crypto parameters once and reuse them for the response.
    local token_bin, key, iv = get_crypto_params(token)

    -- Encrypt the payload using the miIO token-derived key.
    local opts = { cipher = AES_OPTIONS.cipher, iv = iv, padding = AES_OPTIONS.padding }
    local encrypted = security.encrypt_bytes(payload, key, opts)

    -- Build the header: magic, length, reserved bytes, device id, and timestamp.
    local device_id = device:get_field(DEV_ID)
    local timestamp = os.time() - device:get_field(TIME_OFFSET)
    local length = HEADER_SIZE + #encrypted
    local header = string.pack(">c2 I2 I4 I4 I4", "\x21\x31", length, 0, device_id, timestamp) .. token_bin

    -- Replace the token bytes with the packet checksum.
    local checksum = md5.sum(header .. encrypted)
    header = header:sub(1, 16) .. checksum

    -- Return the message with the key and IV used to decrypt the response.
    return header .. encrypted, key, iv
end

-- Send one MIoT command and decode its response.
local function send_command(device, ip, token, method, params, retry)
    local udp = create_udp()

    -- Reuse the request crypto parameters for response decryption.
    local message, key, iv = create_message(device, ip, token, method, params, retry)
    udp:sendto(message, ip, PORT)

    -- Receive the device response.
    local response = udp:receive()
    udp:close()

    if not response then error("No response from device") end

    -- Decrypt the response with the request key and IV.
    local encrypted_data = response:sub(HEADER_SIZE + 1)
    local opts = { cipher = AES_OPTIONS.cipher, iv = iv, padding = AES_OPTIONS.padding }
    local decrypted = security.decrypt_bytes(encrypted_data, key, opts)

    return json.decode(decrypted)
end

-- Retry once after resetting the handshake state.
local function send_with_retry(device, ip, token, method, params)
    -- First attempt uses the current cached handshake.
    local ok, response = pcall(send_command, device, ip, token, method, params, false)
    if ok then return response end

    -- A transport failure can mean stale handshake state.
    clear_device_cache(device)
    return send_command(device, ip, token, method, params, true)
end

-- Public API

-- Read one MIoT property.
function miot.get(device, ip, token, siid, piid)
    return send_with_retry(device, ip, token, "get_properties", {
        {
            did = string.format("prop.%d.%d", siid, piid),
            siid = siid,
            piid = piid
        }
    })
end

-- Write one MIoT property.
function miot.set(device, ip, token, siid, piid, value)
    local response = send_with_retry(device, ip, token, "set_properties", {
        {
            did = string.format("set.%d.%d", siid, piid),
            siid = siid,
            piid = piid,
            value = value
        }
    })
    return assert_success(response)
end

-- Read multiple MIoT properties, batching requests to the device limit.
function miot.gets(device, ip, token, properties)
    local combined_response = nil
    local combined_result = {}

    for first = 1, #properties, MAX_PROPERTIES_PER_REQUEST do
        local batch = {}
        local last = math.min(first + MAX_PROPERTIES_PER_REQUEST - 1, #properties)
        for index = first, last do
            local property = properties[index]
            table.insert(batch, {
                did = property.did or string.format("prop.%d.%d", property.siid, property.piid),
                siid = property.siid,
                piid = property.piid
            })
        end

        local response = send_with_retry(device, ip, token, "get_properties", batch)
        if not response or not response.result then
            return response
        end

        combined_response = combined_response or response
        for _, result in ipairs(response.result) do
            table.insert(combined_result, result)
        end
    end

    combined_response = combined_response or { result = {} }
    combined_response.result = combined_result
    return combined_response
end

-- Invoke one MIoT action.
function miot.action(device, ip, token, siid, aiid, params)
    local response = send_with_retry(device, ip, token, "action", {
        did = string.format("call.%d.%d", siid, aiid),
        siid = siid,
        aiid = aiid,
        ["in"] = params or {}
    })
    return assert_success(response)
end

-- Send an explicit MIoT RPC command.
function miot.cmd(device, ip, token, method, params)
    return send_with_retry(device, ip, token, method, params)
end

return miot
