import { describe, expect, test } from "bun:test";
import { hex, inputs, packet } from "./ddc";

const text = (code: number) =>
  packet(code)
    .map((byte) => hex(byte.value))
    .join(" ");

describe("packet", () => {
  test("switches to DisplayPort, HDMI and Thunderbolt", () => {
    expect(text(0x0f)).toBe("6E 51 84 03 60 00 0F D7");
    expect(text(0x11)).toBe("6E 51 84 03 60 00 11 C9");
    expect(text(0x15)).toBe("6E 51 84 03 60 00 15 CD");
  });

  test("the checksum always cancels the rest out", () => {
    for (let code = 0; code < 0x200; code++) {
      expect(packet(code).reduce((sum, byte) => sum ^ byte.value, 0)).toBe(0);
    }
  });

  test("splits a two byte value", () => {
    expect(packet(0x1234).slice(5, 7).map((byte) => byte.value)).toEqual([0x12, 0x34]);
  });

  test("every input on the page has its own code", () => {
    expect(new Set(inputs.map((input) => input.code)).size).toBe(inputs.length);
  });
});

test("hex is always two digits", () => {
  expect([0, 9, 0xab].map(hex)).toEqual(["00", "09", "AB"]);
});
