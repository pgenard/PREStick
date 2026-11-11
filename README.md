# 🛠️ PREStick: PRESENT-128 on iCEStick 🧊 FPGA.

## Project Overview

This project originally explored implementing an **AES** cryptographic core on a small FPGA.

During development, the limited hardware resources of the **iCE40 HX1K** became an important design consideration. **AES** implementations with iterative or combinational substitution logic consume a significant portion of the available FPGA logic cells.

Therefore, I decided to explore **PRESENT-128**, a lightweight block cipher specifically designed for resource-constrained hardware.

The result is a working FPGA encryption system that receives data through a serial interface, encrypts it using **PRESENT-128** core, and returns the ciphertext to the host computer.

## Hardware
- FPGA: Lattice **iCE40 HX1K**
- Development board: **iCEStick**
- Package: **TQ144**
- FPGA clock: 12 MHz
- Communication: UART
- Baud rate: 115200
- FPGA toolchain: **Yosys**, **nextpnr-ice40** and **IceStorm**

**PRESENT** smaller substitution logic makes it attractive for small FPGA devices.

Important: **PRESENT** is an educational and research-oriented lightweight cipher.

It should not be considered a drop-in replacement for **AES** in modern security-sensitive applications.

## Architecture

The system consists of three main components:

1. UART receiver
2. **PRESENT-128** encryption core
3. UART transmitter

### Verified Test Vector

The following test vector was successfully verified in simulation and on the physical **iCEStick**.

| Parameter           | Value                              |
|---------------------|------------------------------------|
| Key                 | `00000000000000000000000000000000` |
| Plaintext           | `0000000000000000`                 |
| Expected ciphertext | `96DB702A2E6900AF`                 |
| Actual ciphertext   | `96DB702A2E6900AF`                 |

**Result: PASS**

### Communication Protocol

The FPGA expects two hexadecimal input lines.
1. First line: 128-bit encryption key (32 hexadecimal characters).
2. Second line: 64-bit plaintext (16 hexadecimal characters).

The FPGA then encrypts the plaintext and transmits a 16-character hexadecimal ciphertext followed by a newline.

This architecture was selected to make the cipher practical within the limited resources of the **iCE40 HX1K**.

### FPGA Resource Utilization

The final successful implementation produced the following **nextpnr** results:

| Resource	         | Utilization |
|------------------------|-------------|
| ICESTORM_LC	         | 1166 / 1280 |
| Logic cell utilization | 91%         |
| ICESTORM_RAM	         | 0 / 16      |
| SB_IO	                 | 3 / 112     |
| SB_GB	                 | 8 / 8       |
| ICESTORM_PLL	         | 0 / 1       |

The design successfully passed placement and routing.

The timing analysis reported:

- Maximum frequency: 85.81 MHz
- Target frequency: 12 MHz
- Timing constraint: PASS

The implementation therefore fits within the **HX1K** device, although it uses a substantial proportion of its available logic resources.

### Building

```bash
iverilog -g2001 -Wall -s tb_present128 -o present present128_core.v tb_present128.v
```

```bash
iverilog -g2001 -Wall -s tb_uart_present -o uart present128_core.v uart_rx.v uart_tx.v top.v tb_uart_present.v
```

### Simulating

```bash
vvp present
```

```bash
vvp uart
```

Expected results:

```text
--------------------------------
PRESENT-128 TEST
--------------------------------
KEY        = 00000000000000000000000000000000
PLAINTEXT  = 0000000000000000
CIPHERTEXT = 96db702a2e6900af
RESULT: PASS
--------------------------------
tb_present128.v:111: $finish called at 6746000 (1ps)
```

```text
=======================
UART + PRESENT-128 TEST
=======================

Sending PRESENT-128 key...
Sending plaintext...

Sending plaintext terminator...
Waiting for FPGA ciphertext...

96DB702A2E6900AF

------------------------------------
EXPECTED CIPHERTEXT:
96DB702A2E6900AF

RECEIVED CIPHERTEXT:
96db702a2e6900af
------------------------------------

```

### Synthesis

```bash
yosys -p "read_verilog present128_core.v uart_rx.v uart_tx.v top.v
          synth_ice40 -top top -json present_uart.json"
```

### Place and Route

```bash
nextpnr-ice40 --hx1k --package tq144 --json present_uart.json --pcf icestick.pcf --asc present_uart.asc --freq 12
```

### Bitstream

```bash
icepack present_uart.asc present_uart.bin
```

### Prog

```bash
iceprog present_uart.bin
```

```text
cat iceprog.output 
pierre@pierre:~/AEStick$ iceprog present_uart.bin
init..
cdone: high
reset..
cdone: low
flash ID: 0x20 0xBA 0x16 0x10 0x00 0x00 0x23 0x72 0x21 0x19 0x18 0x00 0x89 0x00 0x43 0x17 0x07 0x17 0x51 0x09
file size: 32220
erase 64kB sector at 0x000000..
programming..
done.                 
reading..
VERIFY OK             
cdone: high
Bye.
```

### Target Validation

```text
pierre@pierre:~/AEStick$ picocom -b 115200 --flow n /dev/ttyUSB1
picocom v3.1

port is        : /dev/ttyUSB1
flowcontrol    : none
baudrate is    : 115200
parity is      : none
databits are   : 8
stopbits are   : 1
escape is      : C-a
local echo is  : no
noinit is      : no
noreset is     : no
hangup is      : no
nolock is      : no
send_cmd is    : sz -vv
receive_cmd is : rz -vv -E
imap is        : 
omap is        : 
emap is        : crcrlf,delbs,
logfile is     : none
initstring     : none
exit_after is  : not set
exit is        : no

Type [C-a] [C-h] to see available commands
Terminal ready
96DB702A2E6900AF

Terminating...
Thanks for using picocom
```

### Security Considerations

**PRESENT-128** is a lightweight block cipher, not a direct substitute for **AES** in modern security-sensitive systems.

The implementation does not provide protection against physical side-channel attacks.

It should not be used to protect sensitive production data.

### Acknowledgements

This project builds on the open-source FPGA development ecosystem:
- Lattice **iCE40** FPGA family
- **Yosys**
- **nextpnr**
- **IceStorm**
- **Icarus Verilog**

Special thanks to the developers and contributors maintaining the open-source **iCE40** FPGA toolchain.

## Author
**Pierre GENARD**

### iCE40, so Low Power it is Cold as iCE🧊
