# `sqrt_ip_driver` - Parallel Square Root Hardware Accelerator Driver

## 📝 Project Overview

This project implements a **Linux Platform Device Driver** for a custom **Hardware Accelerator** on a **Xilinx Zynq** platform (typically a development board like the **Zybo**).

The system integrates **four parallel Square Root Hardware IP cores** deployed in the Programmable Logic (PL). The driver, running on the ARM Processor System (PS), uses **AXI4-Lite** to communicate with the cores, enabling efficient, parallel calculation of integer square roots. The driver exposes a character device (`/dev/sqrt`) for user space I/O and manages a set of **LEDs** to visualize the activity of the accelerator cores.

---

## 💡 System Architecture

### Hardware IP Cores

The system utilizes five memory-mapped IP cores. The driver finds these resources via the Linux Device Tree.

| Component Name | Device Tree Compatible String | Role | Status Indication |
| :--- | :--- | :--- | :--- |
| **LED GPIO** | `led_gpio` | Controls 4 LEDs to show core activity. | Bits 3 through 0 of the LED register. |
| **SQRT Cores 0-3** | `mysqrtip_<n>` | Calculates $Y = \lfloor\sqrt{X}\rfloor$ in hardware. | LEDs 3 (Core 0) through 0 (Core 3). |

### Hardware IP Register Map

Each `mysqrtip` core uses the following 32-bit registers (accessed by the driver):

| Register Name | Offset | Access | Description |
| :--- | :--- | :--- | :--- |
| **REG\_X** | `0x0` | Write | **Input:** The number $X$ for calculation. |
| **REG\_START** | `0x4` | Write | **Control:** Write `1` then `0` to start the computation. |
| **REG\_Y** | `0x8` | Read | **Output:** The resulting integer square root $\lfloor\sqrt{X}\rfloor$. |
| **REG\_READY** | `0xc` | Read | **Status:** Reads `1` when computation is complete. |

---

## 🛠️ Driver Implementation Details

### Parallel Execution and Synchronization

The core logic resides in the `obrada` function, which orchestrates parallel execution:

1.  **Workload Distribution:** Input numbers (up to 1000) are stored in the `numbers` array and dispatched in batches of four to the `REG_X` register of the four IP cores.
2.  **Core Activation:** Each core is pulsed via the **REG\_START** pulse, and the corresponding LED is switched **ON** to indicate activity.
3.  **Synchronization (Busy-Polling):** The driver employs a **busy-waiting** synchronization mechanism (`goto waitX`) to continuously poll the **REG\_READY** register of each core until the result is available.
    * *Note: This polling approach is non-blocking to the cores but is CPU-intensive. A production driver would typically use interrupts.*
4.  **Result Retrieval:** Once a core is ready, the result is read from **REG\_Y**, stored in the global `korijeni` array, and the core's LED is switched **OFF**.

### Character Device Interface (`/dev/sqrt`)

* **`sqrt_write`:** Parses space-separated unsigned integers from user space and stores them in the `numbers` array. It then calls `obrada()` to start hardware processing.
* **`sqrt_read`:** Returns the calculated results in a line-by-line format: `"broj <index> - <input>:<result> \n"`.

---

## 🚀 Usage Guide

### 1. Building and Loading the Module

1.  **Build:** Compile the kernel module (`sqrt.c`) using your cross-compilation environment and Makefile:
    ```bash
    make
    ```
2.  **Load:** Load the driver onto the target Zynq system:
    ```bash
    sudo insmod sqrt.ko
    ```
3.  **Verify Device:** The character device should be created:
    ```bash
    ls -l /dev/sqrt
    ```

### 2. Basic Single-Batch Calculation

Interact with the hardware using standard Linux I/O commands:

1.  **Send Input:** Write a batch of numbers to the device.
    ```bash
    echo "100 25 16 9" > /dev/sqrt
    ```
2.  **Read Output:** Read the results after the LEDs indicate processing is complete.
    ```bash
    cat /dev/sqrt
    ```
    *(Example Output: `broj 0 - 100:10`)*

---

## 🧪 Stress Testing Application

The provided C application, `stress_test.c`, is used to verify the driver's operation and expose potential concurrency issues by simultaneously writing new calculation requests and reading previous results using multiple threads.

### Building the Stress Test App

1.  **Save the Code:** Save the provided C code as `stress_test.c`.
2.  **Compile:** Compile the application on the Zynq's Linux environment, linking against the `pthread` library:
    ```bash
    gcc stress_test.c -o stress_test -lm -lpthread
    ```

### Running the Test

1.  **Execute:** Run the compiled application.
    ```bash
    sudo ./stress_test
    ```

2.  **Behavior:**
    * The **Write Thread** generates random squared numbers and writes them to `/dev/sqrt` every 1-5 seconds.
    * The **Read Thread** reads the results from `/dev/sqrt` every 3-5 seconds and **verifies** that the calculated square root ($Y$) is correct by confirming that $Y \times Y = X$.
