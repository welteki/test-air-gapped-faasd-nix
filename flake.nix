{
  description = "Test air-gapped faasd deployment";

  inputs = {
    nixpkgs.follows = "faasd/nixpkgs";

    faasd.url = "github:welteki/faasd-nix/seed-images";

    nixos-shell = {
      url = "github:welteki/nixos-shell/improve-flake-support";
      inputs.nixpkgs.follows = "faasd/nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "faasd/nixpkgs";
    };
  };

  outputs = { self, nixpkgs, faasd, nixos-shell, nixos-generators, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ faasd.overlay ];
      };

      faasdServer =
        { pkgs, ... }:
        let
          figlet = pkgs.dockerTools.pullImage {
            imageName = "ghcr.io/openfaas/figlet";
            imageDigest = "sha256:98b7e719cabe654a7d2f8ff0f3c11294ef737a1f1e4eeef7321277420dfebe8d";
            finalImageTag = "latest";
            sha256 = "sha256-leYfLXQ4cCvPOudU82UaV9BkUIA+W6YvM0zx3BlyCjw=";
          };

          nodeInfo = pkgs.dockerTools.pullImage {
            imageName = "ghcr.io/openfaas/nodeinfo";
            imageDigest = "sha256:018db1b62c35acf63ff79be5e252128b2477c134421fe1322c159438edf6bcaf";
            finalImageTag = "stable";
            sha256 = "sha256-1hOPmt9fKdQUPokVhx9C62XYYC9iZ++QVI/iEb5+/Hk=";
          };
        in
        {
          imports = [ faasd.nixosModules.faasd ];

          services.faasd = {
            enable = true;
            seedCoreImages = true;
            seedDockerImages = [
              {
                namespace = "openfaas-fn";
                imageFile = figlet;
              }
              {
                namespace = "openfaas-fn";
                imageFile = nodeInfo;
              }
            ];
            pullPolicy = "IfNotPresent";
          };

          environment.systemPackages = [ pkgs.faas-cli ];

          services.openssh = {
            enable = true;
            passwordAuthentication = false;
          };

          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDh4g/DLrLpZOh7/pjXYnRI/aaX3STRzPNbpuIAVYTY7ROB1xPN9o0pUzvFZdJAVf74twBUmXv4FElzKS6eG+JXEKqQjGYMA82fKXHoRfgrRGEYc+wE7xodqO7VQxgnNhdVFe6BtVOyL8M8amjZU7z7DTfhFP0oQ4TBjqO7BnUMGLkARTZGCYvnIHXSYUQc7fk/Ejj5HeFWK+j9F6l1xhvE+n/1FDitvxTMTuQ52vSk5SynP7WMPcNtrfnLTcgcxOw0deDU57d18Ts64lYG+IHiZsTUaNqUmTum1SuIsAPY4trFDXs5B0X6ma364I34OyH1o3+lsnWsZC9EjlwKdjs33YGKec05OXq7qfHWO6Myj7SQrFDkFQCst6buMVJpf+ZfSym2vGs/6uOtTmK4zy1f3dW96esaY5ZaFPp4h+4GZ46Ok96iWfkbFfArabQUa5YkfV37gjmP7J1bz0AgVxuMM69hz4qtMpgvOEyXbAe5+Ex7WCIw3CeEWJjs20km6DhHzLmOmrBA4e+4llFH9357LwF+z3a6Cxyjw2h8vyt64+OSSjncd0cgFmi+32Pfl93iXqAgzlNYKlZtJZotKxhIJoWgYV7wziv/RjVw5IyJ/SLsBKRk36JWxYlGaKWbaxQoAZZSTGbTi8hfxx5VmNscL52turiEOSP7G8lXVrofBQ== welteki"
          ];
        };
    in
    {
      nixosConfigurations.faasd-vm = nixos-shell.lib.nixosShellSystem {
        inherit system;
        modules = [ faasdServer (args: { nixos-shell.mounts.mountHome = false; }) ];
      };

      packages.x86_64-linux = {
        faasd-virtualbox-image = nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [ faasdServer ];
          format = "virtualbox";
        };
      };

      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = [
          nixos-shell.defaultPackage.x86_64-linux
        ];
      };
    };
}
