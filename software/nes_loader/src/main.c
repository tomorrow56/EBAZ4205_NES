/**
 * main.c
 * NES ROM Loader for EBAZ4205 (Zynq-7000 PS bare-metal)
 *
 * Function:
 *   1. Initialize SD card (SDIO0 via FatFs)
 *   2. Read /nes/game.nes from FAT32 filesystem
 *   3. Parse iNES header to extract PRG ROM and CHR ROM
 *   4. Write PRG ROM to AXI BRAM at 0x40000000 (32KB)
 *   5. Write CHR ROM to AXI BRAM at 0x40008000 (8KB)
 *   6. Release NES core reset via GPIO EMIO
 *   7. Monitor nes_ready signal
 *
 * AXI Memory Map:
 *   0x4000_0000 - 0x4000_7FFF : PRG ROM BRAM (32KB)
 *   0x4000_8000 - 0x4000_9FFF : CHR ROM BRAM (8KB)
 *
 * GPIO EMIO:
 *   GPIO[0] (output): nes_rst_n  (0=reset, 1=run)
 *   GPIO[1] (input):  nes_ready  (1=NES core running)
 *
 * Build with Vitis (Xilinx SDK):
 *   - Platform: zynq_ps_bd_wrapper
 *   - Domain: standalone (bare-metal)
 *   - BSP libraries: xilffs (FatFs), xilgpio
 */

#include <stdio.h>
#include <string.h>
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xgpiops.h"
#include "ff.h"          /* FatFs (xilffs) */
#include "sleep.h"

/* =========================================================================
 * Configuration
 * ========================================================================= */

/* NES ROM file path on SD card (FAT32) */
#define NES_ROM_PATH        "/nes/game.nes"

/* AXI BRAM base addresses */
#define PRG_ROM_BASE_ADDR   0x40000000UL    /* 32KB PRG ROM */
#define CHR_ROM_BASE_ADDR   0x40008000UL    /* 8KB  CHR ROM */
#define PRG_ROM_SIZE        (32 * 1024)     /* 32KB */
#define CHR_ROM_SIZE        (8  * 1024)     /* 8KB  */

/* GPIO EMIO pin numbers (EMIO starts at MIO count = 54 for Zynq-7010) */
#define GPIO_EMIO_OFFSET    54
#define GPIO_NES_RST_N      (GPIO_EMIO_OFFSET + 0)  /* output: NES reset (active-low) */
#define GPIO_NES_READY      (GPIO_EMIO_OFFSET + 1)  /* input:  NES ready */

/* UART baud rate for debug output */
#define UART_BAUD_RATE      115200

/* =========================================================================
 * iNES Header Structure
 * ========================================================================= */

#define INES_MAGIC          0x1A53454E  /* "NES\x1A" in little-endian */

typedef struct {
    uint8_t  magic[4];      /* "NES\x1A" */
    uint8_t  prg_rom_pages; /* Number of 16KB PRG ROM pages */
    uint8_t  chr_rom_pages; /* Number of 8KB CHR ROM pages (0 = CHR RAM) */
    uint8_t  flags6;        /* Mapper, mirroring, battery, trainer */
    uint8_t  flags7;        /* Mapper, VS/Playchoice, NES 2.0 */
    uint8_t  flags8;        /* PRG RAM size */
    uint8_t  flags9;        /* TV system (rarely used) */
    uint8_t  flags10;       /* TV system, PRG RAM presence (unofficial) */
    uint8_t  padding[5];    /* Unused padding */
} ines_header_t;

/* =========================================================================
 * Global variables
 * ========================================================================= */

static FATFS   fatfs;
static FIL     fil;
static XGpioPs gpio;

/* Work buffer for file I/O */
static uint8_t io_buf[4096];

/* =========================================================================
 * Function prototypes
 * ========================================================================= */

static int  gpio_init(void);
static void nes_reset_assert(void);
static void nes_reset_release(void);
static int  sd_mount(void);
static int  load_nes_rom(const char *path);
static int  write_bram(uint32_t base_addr, const uint8_t *data, uint32_t size);
static void print_ines_info(const ines_header_t *hdr);

/* =========================================================================
 * Main
 * ========================================================================= */

int main(void)
{
    int ret;

    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  EBAZ4205 NES Loader (tarunes port)\r\n");
    xil_printf("========================================\r\n");
    xil_printf("\r\n");

    /* Step 1: Initialize GPIO and assert NES reset */
    xil_printf("[1/5] Initializing GPIO...\r\n");
    ret = gpio_init();
    if (ret != XST_SUCCESS) {
        xil_printf("ERROR: GPIO initialization failed (%d)\r\n", ret);
        return -1;
    }
    nes_reset_assert();
    xil_printf("      GPIO OK. NES core held in reset.\r\n");

    /* Step 2: Mount SD card */
    xil_printf("[2/5] Mounting SD card...\r\n");
    ret = sd_mount();
    if (ret != 0) {
        xil_printf("ERROR: SD card mount failed (%d)\r\n", ret);
        return -1;
    }
    xil_printf("      SD card mounted OK.\r\n");

    /* Step 3: Load NES ROM */
    xil_printf("[3/5] Loading NES ROM: %s\r\n", NES_ROM_PATH);
    ret = load_nes_rom(NES_ROM_PATH);
    if (ret != 0) {
        xil_printf("ERROR: ROM loading failed (%d)\r\n", ret);
        return -1;
    }
    xil_printf("      ROM loaded OK.\r\n");

    /* Step 4: Wait a moment for BRAM writes to settle */
    xil_printf("[4/5] Waiting for BRAM writes to settle...\r\n");
    usleep(10000);  /* 10ms */

    /* Step 5: Release NES reset */
    xil_printf("[5/5] Releasing NES core reset...\r\n");
    nes_reset_release();

    /* Wait for NES ready signal */
    xil_printf("      Waiting for NES core ready...\r\n");
    uint32_t timeout = 1000000;
    while (timeout > 0) {
        uint32_t ready = XGpioPs_ReadPin(&gpio, GPIO_NES_READY);
        if (ready) {
            xil_printf("      NES core is RUNNING!\r\n");
            break;
        }
        timeout--;
        usleep(1);
    }
    if (timeout == 0) {
        xil_printf("WARNING: NES ready timeout. Check PL bitstream.\r\n");
    }

    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  NES Loader complete. Enjoy the game!\r\n");
    xil_printf("========================================\r\n");

    /* Main loop: monitor status */
    while (1) {
        uint32_t ready = XGpioPs_ReadPin(&gpio, GPIO_NES_READY);
        if (!ready) {
            xil_printf("WARNING: NES core stopped unexpectedly.\r\n");
        }
        sleep(5);
    }

    return 0;
}

/* =========================================================================
 * GPIO initialization
 * ========================================================================= */

static int gpio_init(void)
{
    XGpioPs_Config *cfg;
    int ret;

    cfg = XGpioPs_LookupConfig(XPAR_PS7_GPIO_0_DEVICE_ID);
    if (cfg == NULL) {
        return XST_FAILURE;
    }

    ret = XGpioPs_CfgInitialize(&gpio, cfg, cfg->BaseAddr);
    if (ret != XST_SUCCESS) {
        return ret;
    }

    /* Configure GPIO EMIO pins:
     *   GPIO[0] (nes_rst_n): output
     *   GPIO[1] (nes_ready): input
     */
    XGpioPs_SetDirectionPin(&gpio, GPIO_NES_RST_N, 1);  /* output */
    XGpioPs_SetOutputEnablePin(&gpio, GPIO_NES_RST_N, 1);

    XGpioPs_SetDirectionPin(&gpio, GPIO_NES_READY, 0);  /* input */
    XGpioPs_SetOutputEnablePin(&gpio, GPIO_NES_READY, 0);

    return XST_SUCCESS;
}

static void nes_reset_assert(void)
{
    XGpioPs_WritePin(&gpio, GPIO_NES_RST_N, 0);  /* active-low: assert reset */
}

static void nes_reset_release(void)
{
    XGpioPs_WritePin(&gpio, GPIO_NES_RST_N, 1);  /* active-low: release reset */
}

/* =========================================================================
 * SD card mount
 * ========================================================================= */

static int sd_mount(void)
{
    FRESULT res;

    res = f_mount(&fatfs, "0:/", 1);
    if (res != FR_OK) {
        xil_printf("      f_mount error: %d\r\n", (int)res);
        return (int)res;
    }
    return 0;
}

/* =========================================================================
 * NES ROM loading
 * ========================================================================= */

static int load_nes_rom(const char *path)
{
    FRESULT    res;
    UINT       br;
    ines_header_t hdr;
    uint32_t   prg_size, chr_size;
    uint32_t   bytes_written;
    uint32_t   bram_addr;
    uint32_t   remaining;
    uint32_t   chunk;

    /* Open file */
    res = f_open(&fil, path, FA_READ);
    if (res != FR_OK) {
        xil_printf("      f_open error: %d (file not found?)\r\n", (int)res);
        return (int)res;
    }

    /* Read iNES header (16 bytes) */
    res = f_read(&fil, &hdr, sizeof(ines_header_t), &br);
    if (res != FR_OK || br != sizeof(ines_header_t)) {
        xil_printf("      Header read error: %d\r\n", (int)res);
        f_close(&fil);
        return -1;
    }

    /* Validate magic number */
    if (hdr.magic[0] != 'N' || hdr.magic[1] != 'E' ||
        hdr.magic[2] != 'S' || hdr.magic[3] != 0x1A) {
        xil_printf("      ERROR: Not a valid iNES file!\r\n");
        f_close(&fil);
        return -2;
    }

    print_ines_info(&hdr);

    /* Calculate ROM sizes */
    prg_size = (uint32_t)hdr.prg_rom_pages * 16384;  /* 16KB per page */
    chr_size = (uint32_t)hdr.chr_rom_pages * 8192;   /* 8KB per page */

    /* Check mapper (only Mapper 0 = NROM is supported in this initial port) */
    uint8_t mapper = (hdr.flags6 >> 4) | (hdr.flags7 & 0xF0);
    if (mapper != 0) {
        xil_printf("      WARNING: Mapper %d detected. Only Mapper 0 (NROM) is supported.\r\n", mapper);
        xil_printf("               The game may not work correctly.\r\n");
    }

    /* Skip trainer (512 bytes) if present */
    if (hdr.flags6 & 0x04) {
        xil_printf("      Trainer present, skipping 512 bytes...\r\n");
        res = f_lseek(&fil, f_tell(&fil) + 512);
        if (res != FR_OK) {
            xil_printf("      Trainer skip error: %d\r\n", (int)res);
            f_close(&fil);
            return -3;
        }
    }

    /* -----------------------------------------------------------------------
     * Write PRG ROM to BRAM
     * For NROM-128 (16KB PRG): mirror to fill 32KB BRAM
     * For NROM-256 (32KB PRG): write directly
     * ----------------------------------------------------------------------- */
    xil_printf("      Writing PRG ROM (%lu KB) to BRAM @ 0x%08lX...\r\n",
               prg_size / 1024, PRG_ROM_BASE_ADDR);

    if (prg_size > PRG_ROM_SIZE) {
        xil_printf("      WARNING: PRG ROM (%lu KB) exceeds BRAM size (32KB). Truncating.\r\n",
                   prg_size / 1024);
        prg_size = PRG_ROM_SIZE;
    }

    bram_addr    = PRG_ROM_BASE_ADDR;
    bytes_written = 0;
    remaining    = prg_size;

    while (remaining > 0) {
        chunk = (remaining > sizeof(io_buf)) ? sizeof(io_buf) : remaining;
        res = f_read(&fil, io_buf, chunk, &br);
        if (res != FR_OK || br == 0) {
            xil_printf("      PRG ROM read error: %d\r\n", (int)res);
            f_close(&fil);
            return -4;
        }

        write_bram(bram_addr, io_buf, br);
        bram_addr    += br;
        bytes_written += br;
        remaining    -= br;
    }

    /* Mirror 16KB PRG ROM to upper 16KB for NROM-128 */
    if (hdr.prg_rom_pages == 1) {
        xil_printf("      Mirroring 16KB PRG ROM to upper 16KB (NROM-128)...\r\n");
        /* Copy lower 16KB to upper 16KB via AXI */
        uint32_t src = PRG_ROM_BASE_ADDR;
        uint32_t dst = PRG_ROM_BASE_ADDR + 16384;
        for (uint32_t i = 0; i < 16384; i += 4) {
            uint32_t val = Xil_In32(src + i);
            Xil_Out32(dst + i, val);
        }
    }

    /* -----------------------------------------------------------------------
     * Write CHR ROM to BRAM
     * ----------------------------------------------------------------------- */
    if (chr_size > 0) {
        xil_printf("      Writing CHR ROM (%lu KB) to BRAM @ 0x%08lX...\r\n",
                   chr_size / 1024, CHR_ROM_BASE_ADDR);

        if (chr_size > CHR_ROM_SIZE) {
            xil_printf("      WARNING: CHR ROM (%lu KB) exceeds BRAM size (8KB). Truncating.\r\n",
                       chr_size / 1024);
            chr_size = CHR_ROM_SIZE;
        }

        bram_addr    = CHR_ROM_BASE_ADDR;
        bytes_written = 0;
        remaining    = chr_size;

        while (remaining > 0) {
            chunk = (remaining > sizeof(io_buf)) ? sizeof(io_buf) : remaining;
            res = f_read(&fil, io_buf, chunk, &br);
            if (res != FR_OK || br == 0) {
                xil_printf("      CHR ROM read error: %d\r\n", (int)res);
                f_close(&fil);
                return -5;
            }

            write_bram(bram_addr, io_buf, br);
            bram_addr    += br;
            bytes_written += br;
            remaining    -= br;
        }
    } else {
        xil_printf("      CHR RAM mode (no CHR ROM in file).\r\n");
        /* Zero-fill CHR BRAM for CHR RAM mode */
        for (uint32_t i = 0; i < CHR_ROM_SIZE; i += 4) {
            Xil_Out32(CHR_ROM_BASE_ADDR + i, 0x00000000);
        }
    }

    f_close(&fil);
    return 0;
}

/* =========================================================================
 * Write data buffer to AXI BRAM (word-aligned writes)
 * ========================================================================= */

static int write_bram(uint32_t base_addr, const uint8_t *data, uint32_t size)
{
    uint32_t i;
    uint32_t word;
    uint32_t addr = base_addr;

    /* Write in 4-byte chunks (word-aligned) */
    for (i = 0; i + 3 < size; i += 4) {
        word = ((uint32_t)data[i+0])       |
               ((uint32_t)data[i+1] << 8)  |
               ((uint32_t)data[i+2] << 16) |
               ((uint32_t)data[i+3] << 24);
        Xil_Out32(addr, word);
        addr += 4;
    }

    /* Handle remaining bytes (< 4 bytes) */
    if (i < size) {
        word = 0;
        for (uint32_t j = 0; j < (size - i); j++) {
            word |= ((uint32_t)data[i+j] << (j * 8));
        }
        Xil_Out32(addr, word);
    }

    return 0;
}

/* =========================================================================
 * Print iNES header information
 * ========================================================================= */

static void print_ines_info(const ines_header_t *hdr)
{
    uint8_t mapper    = (hdr->flags6 >> 4) | (hdr->flags7 & 0xF0);
    uint8_t mirroring = (hdr->flags6 & 0x01) ? 1 : 0;  /* 0=horizontal, 1=vertical */
    uint8_t battery   = (hdr->flags6 & 0x02) ? 1 : 0;
    uint8_t trainer   = (hdr->flags6 & 0x04) ? 1 : 0;

    xil_printf("      --- iNES Header ---\r\n");
    xil_printf("      PRG ROM: %d x 16KB = %d KB\r\n",
               hdr->prg_rom_pages, hdr->prg_rom_pages * 16);
    xil_printf("      CHR ROM: %d x 8KB  = %d KB%s\r\n",
               hdr->chr_rom_pages, hdr->chr_rom_pages * 8,
               hdr->chr_rom_pages == 0 ? " (CHR RAM)" : "");
    xil_printf("      Mapper:  %d\r\n", mapper);
    xil_printf("      Mirror:  %s\r\n", mirroring ? "Vertical" : "Horizontal");
    xil_printf("      Battery: %s\r\n", battery ? "Yes" : "No");
    xil_printf("      Trainer: %s\r\n", trainer ? "Yes" : "No");
    xil_printf("      -------------------\r\n");
}
