export const inputs = [
  { name: "DisplayPort", code: 0x0f },
  { name: "HDMI", code: 0x11 },
  { name: "Thunderbolt", code: 0x15 },
] as const;

const DISPLAY = 0x6e;
const HOST = 0x51;
const SET = 0x03;
const INPUT = 0x60;

export type Byte = { value: number; name: string };

/** The bytes that ask a monitor to switch input, checksum and all. */
export function packet(code: number): Byte[] {
  const bytes: Byte[] = [
    { value: DISPLAY, name: "Monitor" },
    { value: HOST, name: "Mac" },
    { value: 0x80 | 4, name: "Length" },
    { value: SET, name: "Set" },
    { value: INPUT, name: "Input" },
    { value: code >> 8, name: "High" },
    { value: code & 0xff, name: "Low" },
  ];
  return [...bytes, { value: bytes.reduce((sum, byte) => sum ^ byte.value, 0), name: "Checksum" }];
}

export const hex = (value: number) => value.toString(16).toUpperCase().padStart(2, "0");
