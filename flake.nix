{
  description = "Bramble is a rp2040 emulator. This flake helps with the building of bramble";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { ... }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system: f { pkgs = import inputs.nixpkgs { inherit system; }; }
        );

      mkBramble =
        pkgs:
        pkgs.stdenv.mkDerivation {
          pname = "bramble";
          version = "unstable-2026-02-04";

          src = pkgs.fetchFromGitHub {
            owner = "Night-Traders-Dev";
            repo = "Bramble";
            rev = "9eeea2470c1fa51319510e34d2206dee5a4d6725";
            sha256 = "sha256-GXSICtaEFfcoY9ssT4CScNLbgxWzsTq1NR8u4WtjQl8=";
          };
          nativeBuildInputs = [
            pkgs.gnumake
            pkgs.pkg-config
            pkgs.cmake

          ];
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp bramble $out/bin/
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "A from-scratch ARM Cortex-M0+ emulator for the Raspberry Pi RP2040 microcontroller";
            homepage = "https://github.com/Night-Traders-Dev/Bramble";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

      mkBcompile =
        pkgs:
        let
          linkerScript = pkgs.writeText "linker.ld" ''
             /* Linker Script for Bramble RP2040 Emulator
             * 
             * This linker script ensures:
             * 1. Vector table placed at 0x10000100 (after boot2)
             * 2. Reset handler is immediately after vector table
             * 3. All sections properly aligned
             * 4. Memory regions defined correctly
             */

            MEMORY
            {
                /* Flash (XIP) - Code and read-only data */
                /* Boot2 occupies 0x10000000-0x100000FF (256 bytes) */
                /* User app starts at 0x10000100 */
                FLASH (rx) : ORIGIN = 0x10000100, LENGTH = 2M - 256
                
                /* RAM - Data and stack */
                RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 264K
            }

            SECTIONS
            {
                /* Vector table (must be first in output) */
                .vectors :
                {
                    KEEP(*(.vectors))
                    . = ALIGN(4);
                } > FLASH

                /* Code and read-only data */
                .text :
                {
                    *(.text*)
                    *(.rodata*)
                    . = ALIGN(4);
                } > FLASH

                /* Initialized data (in flash, copied to RAM at startup) */
                .data :
                {
                    _data_start = .;
                    *(.data*)
                    _data_end = .;
                    . = ALIGN(4);
                } > RAM AT > FLASH
                
                _data_lma = LOADADDR(.data);

                /* Uninitialized data (RAM only, zeroed at startup) */
                .bss :
                {
                    _bss_start = .;
                    *(.bss*)
                    *(COMMON)
                    _bss_end = .;
                    . = ALIGN(4);
                } > RAM

                /* Stack and heap (remainder of RAM) */
                .heap :
                {
                    _heap_start = .;
                    . = . + 4K;  /* Reserve 4K for heap */
                    _heap_end = .;
                } > RAM

                /* Stack grows downward from end of RAM */
                _stack_top = ORIGIN(RAM) + LENGTH(RAM);

                /* Debug symbols */
                .debug_info 0 : { *(.debug_info) }
                .debug_abbrev 0 : { *(.debug_abbrev) }
                .debug_line 0 : { *(.debug_line) }
                .debug_loc 0 : { *(.debug_loc) }
            }

            /* Entry point */
            ENTRY(reset_handler)

            /* Symbols for startup code */
            EXTERN(reset_handler) '';
        in
        pkgs.writeShellApplication {
          name = "bcompile";
          runtimeInputs = [
            pkgs.gcc-arm-embedded-13
            pkgs.elf2uf2-rs
          ];

          text = ''

            if [ $# -eq 0 ]; then
              echo "Usage: bbuild <filename_without_extension>"
              exit 1
            fi

            FILENAME="''${1%.S}"
            echo "[1/3] Compiling"
            arm-none-eabi-gcc -mcpu=cortex-m0plus -mthumb -c "$FILENAME.S" -o "$FILENAME.o"

            echo "[2/3] Linking"
            arm-none-eabi-ld -T "${linkerScript}" "$FILENAME.o" -o "$FILENAME.elf"

            echo "[3/3] Converting to uf2"

            elf2uf2-rs "$FILENAME.elf" "$FILENAME.uf2"


            echo "Build complete: $FILENAME.uf2"
          '';
        };
    in
    {
      packages = forEachSupportedSystem (
        { pkgs }:
        {
          bramble = mkBramble pkgs;
          bcompile = mkBcompile pkgs;
        }
      );
    };
}
