{ lib, config, pkgs, ... }: {
  networking.hostName = "amy";
  networking.retiolum = {
    ipv4 = "10.243.29.181";
    ipv6 = "42:0:3c46:1551:1906:bc7c:801f:3c4";
  };

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
        /home/ ${lib.concatMapStringsSep " "
    (host:
          ''${host.ipv4}(rw,nohide,insecure,no_subtree_check,no_root_squash)'')
          (lib.attrValues config.networking.doctorwho.hosts)}
  '';

  services.borgbackup.jobs.joerg = {
    paths = [
      "/home/joerg"
    ];
    doInit = true;
    repo = "borg@eve.thalheim.io:.";
    preHook = ''
      eval $(ssh-agent)
      ssh-add /etc/nixos/secrets/borgbackup-ssh-key
    '';
    postHook = ''
      cat > /var/log/telegraf/borgbackup-amy <<EOF
      task,frequency=daily last_run=$(date +%s)i,state="$([[ $exitStatus == 0 ]] && echo ok || echo fail)"
      EOF
    '';
    extraArgs = "--lock-wait 900";
    encryption.mode = "none";
    compression = "auto,zstd";
    startAt = "daily";
    prune.keep = {
      within = "1d"; # Keep all archives from the last day
      daily = 7;
      weekly = 4;
      monthly = 0;
    };
  };

  systemd.timers.borgbackup-job-joerg = {
    timerConfig.OnCalendar = lib.mkForce "04:00:00";
  };

  services.borgbackup.jobs.all-homes = {
    paths = [
      "/home"
    ];
    doInit = true;
    repo = "/mnt/backup/borgbackup";
    preHook = ''
      ${pkgs.sshfs}/bin/sshfs -oIdentityFile=/etc/nixos/secrets/borgbackup-ssh-key -oPort=22222 s1443541@csce.datastore.ed.ac.uk:/csce/datastore/inf/users/s1443541 /mnt/backup
    '';
    postHook = ''
      cat > /var/log/telegraf/borgbackup-datastore <<EOF
      task,frequency=daily last_run=$(date +%s)i,state="$([[ $exitStatus == 0 ]] && echo ok || echo fail)"
      EOF
    '';
    encryption = {
      mode = "repokey";
      passCommand = "cat /etc/nixos/secrets/borgbackup-password";
    };
    compression = "auto,zstd";
    startAt = "daily";
    prune.keep = {
      within = "1d"; # Keep all archives from the last day
      daily = 7;
      weekly = 4;
      monthly = 0;
    };
  };
  # hide sshfs from the system
  systemd.services.borgbackup-job-all-homes.serviceConfig.PrivateMounts = true;
  systemd.services.borgbackup-job-all-homes.serviceConfig.ReadWritePaths = [ "/var/log/telegraf" ];
  systemd.services.borgbackup-job-joerg.serviceConfig.ReadWritePaths = [ "/var/log/telegraf" ];

  fileSystems."/home" = {
    device = "zroot/root/home";
    fsType = "zfs";
  };

  system.stateVersion = "19.09";
}
