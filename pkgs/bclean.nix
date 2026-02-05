pkgs:
pkgs.writeShellApplication {
  name = "bclean";

  text = ''
    rm ./*.o
    rm ./*.elf
    rm ./*.uf2
  '';
}
