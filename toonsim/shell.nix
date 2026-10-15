# Qt 5.15 for toonsim from nixpkgs (macOS or Linux):  cd toonsim && nix-shell
# then: tools/build.sh   and   ./toonsim.sh   (see AGENTS.md)
{ pkgs ? import <nixpkgs> { } }:
let
  q = pkgs.libsForQt5.qt5;
  qt = [ q.qtbase q.qtdeclarative q.qtquickcontrols q.qtquickcontrols2 q.qtgraphicaleffects
         q.qtvirtualkeyboard q.qtsvg q.qtwebsockets ];
in
pkgs.mkShell {
  packages = qt ++ [ q.qttools pkgs.python3 ];
  # nixpkgs wraps Qt apps; a plain build has to be told where the QML modules and plugins are
  shellHook = ''
    export QML2_IMPORT_PATH=${pkgs.lib.makeSearchPath q.qtbase.qtQmlPrefix qt}
    export QT_PLUGIN_PATH=${pkgs.lib.makeSearchPath q.qtbase.qtPluginPrefix (map pkgs.lib.getBin qt)}
  '';
}
