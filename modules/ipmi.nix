{ pkgs, ... }: {
  boot.kernelParams = [
    "console=ttyS1,115200"
    "console=tty1"
  ];

  environment.systemPackages = [ pkgs.ipmitool ];
}
