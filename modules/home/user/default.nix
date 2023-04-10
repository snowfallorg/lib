{ lib, options, ... }:

let
  inherit (lib) types mkOption mkIf;

  cfg = options.snowfallorg;
in
  # (builtins.trace (cfg.user.name or "no name"))
{
  options.snowfallorg = {
    user = {
      name = mkOption {
        type = types.str;
        description = "The user's name.";
      };
    };
  };

  # config = mkIf ((cfg.user.name or null) != null) {
    # @TODO(jakehamilton): Get user home directory from osConfig if
    # it exists.
  # };
}
