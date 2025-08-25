{ config, pkgs, ... }:

let
  homeDirectory = config.home.homeDirectory;

  expectedConfig = pkgs.writeText "expected-conky-config.conf" ''
    conky.text = [[
      S Y S T E M    I N F O
      $hr
      Host:$alignr $nodename
      Uptime:$alignr $uptime
      RAM:$alignr $mem/$memmax
    ]]
  '';
in
{
  services.conky = {
    configs = {
      withFile = {
        enable = true;
        autoStart = true;
        config = "${homeDirectory}/.config/conky/my-conky.conf";
        package = pkgs.conky;
      };

      withConfig = {
        enable = true;
        autoStart = false;
        config = ''
          conky.text = [[
            S Y S T E M    I N F O
            $hr
            Host:$alignr $nodename
            Uptime:$alignr $uptime
            RAM:$alignr $mem/$memmax
          ]]
        '';
        package = pkgs.conky;
      };
    };
  };

  home.file.".config/conky/my-conky.conf".text = "dummy conky file content";

  nmt.script = ''
    echo "Test 1"
    # --- Test the 'withFile' instance ---
    serviceFile1="$TESTED/home-files/.config/systemd/user/conky@withFile.service"

    echo "Testing $serviceFile1"
    cat "$serviceFile1"

    assertFileExists "$serviceFile1"

    assertFileRegex "$serviceFile1" \
      "ExecStart=.*/bin/conky --config /nix/store/.*-conky-withFile.conf"

    grep -q "\[Install\]" "$serviceFile1" || (echo "ERROR: Missing [Install] section!"; exit 1)
    grep -q "WantedBy=graphical-session.target" "$serviceFile1" || (echo "ERROR: Missing WantedBy key!"; exit 1)

    # --- Test the 'withConfig' instance ---
    echo "Test 2"
    serviceFile2="$TESTED/home-files/.config/systemd/user/conky@withConfig.service"
    echo "Testing $serviceFile2"

    assertFileExists "$serviceFile2"

    assertFileRegex "$serviceFile2" \
      "ExecStart=.*/bin/conky --config /nix/store/.*-conky-withConfig.conf"

    if grep -q "\[Install\]" "$serviceFile2"; then
          echo "ERROR: [Install] section found but should be absent!"
          exit 1
        fi

    generatedConfigFile="$(grep -o '/nix/store/.*-conky-withConfig.conf' "$serviceFile2")"

    assertFileContent "$generatedConfigFile" ${./basic-configuration.conf}

    echo "✅ Conky tests passed!"
  '';
}
