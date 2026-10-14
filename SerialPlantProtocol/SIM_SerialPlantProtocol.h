/*
    Serial plant binary protocol — frame encoding, decoding, and RX
    state machine for communication between a flight controller and an
    external plant simulator over a serial link.

    Wire format:
    [0xA5][0x5A][MSG_ID][LEN_LO][LEN_HI][PAYLOAD...]

    State payload layout (variable length, driven by mask byte):
      byte 0:      mask (bit0=quaternion, bit1=rangefinder, bit2=airspeed, bit3=windvane)
      bytes 1-8:   timestamp  (double)
      bytes 9-20:  gyro       (float*3)
      bytes 21-32: accel_body (float*3)
      bytes 33-56: position   (double*3)
      bytes 57-68: velocity   (float*3)
      bytes 69+:   attitude (float*3) or quaternion (float*4) per mask bit 0
      then optional fields in mask-bit order: rangefinder, airspeed, windvane

*/
#pragma once

#include <stdint.h>
#include <string.h>

/* ---- frame layer ---- */
#define SYNC1          0xA5
#define SYNC2          0x5A
#define MSG_SERVO      0x01
#define MSG_STATE      0x02
#define HEADER_SIZE    5       /* sync(2) + id(1) + len(2) */

/* ---- state mask bits (byte 0 of state payload) ---- */
#define MASK_QUATERNION   (1 << 0)
#define MASK_RANGEFINDER  (1 << 1)
#define MASK_AIRSPEED     (1 << 2)
#define MASK_WINDVANE     (1 << 3)

/* ---- payload sizes ---- */
#define MANDATORY_STATE_LEN  69   /* mask(1) + ts(8) + gyro(12) + acc(12) + pos(24) + vel(12) */
#define STATE_BUF_MAX       121   /* max with all optional + quaternion */
#define SERVO_16_LEN         38   /* count(4) + rate(2) + pwm[16](32) */
#define SERVO_32_LEN         70   /* count(4) + rate(2) + pwm[32](64) */

/* ---- decoded sensor state (plain C types only) ---- */
struct decoded_state {
    uint8_t  mask;
    double   timestamp_s;
    float    gyro[3];
    float    accel_body[3];
    double   position[3];
    float    velocity[3];
    float    attitude[3];        /* roll, pitch, yaw  (mask bit 0 == 0) */
    float    quaternion[4];      /* w, x, y, z        (mask bit 0 == 1) */
    float    rangefinder[6];
    float    airspeed;
    float    windvane_direction;
    float    windvane_speed;
};

/* ---- RX state machine ---- */
enum rx_state {
    RX_SYNC1,
    RX_SYNC2,
    RX_MSG_ID,
    RX_LEN_LO,
    RX_LEN_HI,
    RX_PAYLOAD,
};

struct rx_context {
    enum rx_state state;
    uint8_t  msg_id;
    uint16_t payload_len;
    uint16_t payload_idx;
    uint8_t  buf[STATE_BUF_MAX];
};

/* Reset RX context to initial idle state. */
void rx_init(struct rx_context *ctx);

/*
    Feed one byte into the RX state machine.
    Returns 1 when a complete packet has been assembled
    (msg_id and payload are then available in ctx).
    Returns 0 when more bytes are needed.
*/
int rx_feed_byte(struct rx_context *ctx, uint8_t byte);

/*
    Decode a state payload buffer into the decoded_state struct.
    Returns 0 on success, -1 if the payload is too short or malformed.
*/
int decode_state(const uint8_t *payload, uint16_t len,
                 struct decoded_state *out);

/*
    Encode a complete servo frame (header + payload) into buf.
    Returns the total number of bytes written, or 0 if buf is too small.
    buf must be at least HEADER_SIZE + SERVO_32_LEN bytes.
*/
uint16_t encode_servo_frame(const uint16_t *pwm, uint8_t num_channels,
                            uint32_t frame_count, uint16_t frame_rate_hz,
                            uint8_t *buf, uint16_t buf_size);

/* Write a 5-byte frame header into the provided buffer. */
void write_header(uint8_t *header, uint8_t msg_id, uint16_t payload_len);

