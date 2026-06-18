{
  description = "Jekyll dev environment for ojensen.net";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Ruby environment with Jekyll, the gems listed under
          # `plugins:` in _config.yml, webrick, and kramdown-parser-gfm.
          #
          # webrick is required because Jekyll's HTTP server moved out
          # of Ruby's standard library in Ruby 3; `jekyll serve` will
          # fail with a LoadError without it, even though nothing in
          # _config.yml mentions it.
          #
          # kramdown-parser-gfm is required by the `kramdown: input: GFM`
          # setting in _config.yml. It's a transitive dependency pulled
          # in by that config block, not listed under `plugins:`, so
          # it's easy to miss on a first read of the config.
          rubyEnv = pkgs.ruby.withPackages (ps: with ps; [
            jekyll
            webrick
            kramdown-parser-gfm
            jekyll-paginate
            jekyll-gist
            jemoji
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = [
              rubyEnv
            ];

            shellHook = ''
              # The repo's ./serve script expects $PORT and $IP
              # (a Cloud9-era convention). Default them so plain
              # `./serve` works; override before nix develop if needed.
              export PORT="''${PORT:-4000}"
              export IP="''${IP:-127.0.0.1}"

              echo "Jekyll dev shell ready."
              echo "Run: jekyll serve --watch    (http://localhost:4000)"
              echo "Or:  ./serve                 (uses PORT=$PORT IP=$IP)"
              echo "Or:  jekyll build"
            '';
          };
        });
    };
}
