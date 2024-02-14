{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (builtins) toString baseNameOf dirOf concatStringsSep;
  inherit (core-inputs.nixpkgs.lib) assertMsg last init;

  file-name-regex = "(.*)\\.(.*)$";
in {
  path = rec {
    ## Split a file name and its extension.
    ## Example Usage:
    ## ```nix
    ## split-file-extension "my-file.md"
    ## ```
    ## Result:
    ## ```nix
    ## [ "my-file" "md" ]
    ## ```
    #@ String -> [String]
    split-file-extension = file: let
      match = builtins.match file-name-regex file;
    in
      assert assertMsg (match != null) "lib.snowfall.split-file-extension: File must have an extension to split."; match;

    ## Check if a file name has a file extension.
    ## Example Usage:
    ## ```nix
    ## has-any-file-extension "my-file.txt"
    ## ```
    ## Result:
    ## ```nix
    ## true
    ## ```
    #@ String -> Bool
    has-any-file-extension = file: let
      match = builtins.match file-name-regex (toString file);
    in
      match != null;

    ## Get the file extension of a file name.
    ## Example Usage:
    ## ```nix
    ## get-file-extension "my-file.final.txt"
    ## ```
    ## Result:
    ## ```nix
    ## "txt"
    ## ```
    #@ String -> String
    get-file-extension = file:
      if has-any-file-extension file
      then let
        match = builtins.match file-name-regex (toString file);
      in
        last match
      else "";

    ## Check if a file name has a specific file extension.
    ## Example Usage:
    ## ```nix
    ## has-file-extension "txt" "my-file.txt"
    ## ```
    ## Result:
    ## ```nix
    ## true
    ## ```
    #@ String -> String -> Bool
    has-file-extension = extension: file:
      if has-any-file-extension file
      then extension == get-file-extension file
      else false;

    ## Get the parent directory for a given path.
    ## Example Usage:
    ## ```nix
    ## get-parent-directory "/a/b/c"
    ## ```
    ## Result:
    ## ```nix
    ## "/a/b"
    ## ```
    #@ Path -> Path
    get-parent-directory = snowfall-lib.fp.compose baseNameOf dirOf;

    ## Get the file name of a path without its extension.
    ## Example Usage:
    ## ```nix
    ## get-file-name-without-extension ./some-directory/my-file.pdf
    ## ```
    ## Result:
    ## ```nix
    ## "my-file"
    ## ```
    #@ Path -> String
    get-file-name-without-extension = path: let
      file-name = baseNameOf path;
    in
      if has-any-file-extension file-name
      then concatStringsSep "" (init (split-file-extension file-name))
      else file-name;
  };
}
