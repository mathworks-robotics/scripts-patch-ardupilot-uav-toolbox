/*
    Serial plant binary protocol implementation.
*/

#include "SIM_SerialPlantProtocol.h"

void rx_init(struct rx_context *ctx)
{
    ctx->state       = RX_SYNC1;
    ctx->msg_id      = 0;
    ctx->payload_len = 0;
    ctx->payload_idx = 0;
    memset(ctx->buf, 0, sizeof(ctx->buf));
}

int rx_feed_byte(struct rx_context *ctx, uint8_t byte)
{
    switch (ctx->state) {
    case RX_SYNC1:
        if (byte == SYNC1) {
            ctx->state = RX_SYNC2;
        }
        return 0;

    case RX_SYNC2:
        ctx->state = (byte == SYNC2) ? RX_MSG_ID : RX_SYNC1;
        return 0;

    case RX_MSG_ID:
        ctx->msg_id = byte;
        ctx->state  = RX_LEN_LO;
        return 0;

    case RX_LEN_LO:
        ctx->payload_len = byte;
        ctx->state       = RX_LEN_HI;
        return 0;

    case RX_LEN_HI:
        ctx->payload_len |= ((uint16_t)byte) << 8;
        if (ctx->payload_len == 0) {
            ctx->state = RX_SYNC1;
            return 1;
        }
        if (ctx->payload_len > STATE_BUF_MAX) {
            ctx->state = RX_SYNC1;
            return 0;
        }
        ctx->payload_idx = 0;
        ctx->state       = RX_PAYLOAD;
        return 0;

    case RX_PAYLOAD:
        ctx->buf[ctx->payload_idx++] = byte;
        if (ctx->payload_idx >= ctx->payload_len) {
            ctx->state = RX_SYNC1;
            return 1;
        }
        return 0;
    }
    return 0;
}

int decode_state(const uint8_t *payload, uint16_t len,
                 struct decoded_state *out)
{
    if (len < MANDATORY_STATE_LEN) {
        return -1;
    }

    memset(out, 0, sizeof(*out));

    out->mask = payload[0];

    memcpy(&out->timestamp_s, payload + 1,  8);
    memcpy(out->gyro,         payload + 9,  12);
    memcpy(out->accel_body,   payload + 21, 12);
    memcpy(out->position,     payload + 33, 24);
    memcpy(out->velocity,     payload + 57, 12);

    uint16_t cursor = 69;

    if (out->mask & MASK_QUATERNION) {
        if (cursor + 16 > len) { return -1; }
        memcpy(out->quaternion, payload + cursor, 16);
        cursor += 16;
    } else {
        if (cursor + 12 > len) { return -1; }
        memcpy(out->attitude, payload + cursor, 12);
        cursor += 12;
    }

    if (out->mask & MASK_RANGEFINDER) {
        if (cursor + 24 > len) { return -1; }
        memcpy(out->rangefinder, payload + cursor, 24);
        cursor += 24;
    }

    if (out->mask & MASK_AIRSPEED) {
        if (cursor + 4 > len) { return -1; }
        memcpy(&out->airspeed, payload + cursor, 4);
        cursor += 4;
    }

    if (out->mask & MASK_WINDVANE) {
        if (cursor + 8 > len) { return -1; }
        memcpy(&out->windvane_direction, payload + cursor, 4);
        memcpy(&out->windvane_speed,     payload + cursor + 4, 4);
        cursor += 8;
    }

    return 0;
}

uint16_t encode_servo_frame(const uint16_t *pwm, uint8_t num_channels,
                            uint32_t frame_count, uint16_t frame_rate_hz,
                            uint8_t *buf, uint16_t buf_size)
{
    const uint16_t payload_len = 4 + 2 + (uint16_t)num_channels * 2;
    const uint16_t total       = HEADER_SIZE + payload_len;

    if (total > buf_size) {
        return 0;
    }

    write_header(buf, MSG_SERVO, payload_len);

    uint16_t off = HEADER_SIZE;
    memcpy(buf + off, &frame_count, 4);
    off += 4;
    memcpy(buf + off, &frame_rate_hz, 2);
    off += 2;

    for (uint8_t i = 0; i < num_channels; i++) {
        memcpy(buf + off, &pwm[i], 2);
        off += 2;
    }

    return total;
}

void write_header(uint8_t *header, uint8_t msg_id, uint16_t payload_len)
{
    header[0] = SYNC1;
    header[1] = SYNC2;
    header[2] = msg_id;
    header[3] = (uint8_t)(payload_len & 0xFF);
    header[4] = (uint8_t)(payload_len >> 8);
}

