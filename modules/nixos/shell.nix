{
  pkgs ? import <nixpkgs> {},
}: pkgs.mkShell {
  packages = [
    # pkgs.podman       # podman cli
    # pkgs.openssl      # cert/handshake debugging
  ];
}
