# This code is adapted from flake-utils-plus:
# https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/2bf0f91643c2e5ae38c1b26893ac2927ac9bd82a/lib/options.nix
{
  lib,
  config,
  user-inputs,
  core-inputs,
  ...
}: {
  disabledModules = [
    # The module from flake-utils-plus only works on NixOS and nix-darwin. For home-manager
    # to build, this module needs to be disabled.
    "${core-inputs.flake-utils-plus}/lib/options.nix"
  ];
}
