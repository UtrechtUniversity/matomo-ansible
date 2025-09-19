# matomo-ansible
Ansible playbook and Docker Compose setup for Matomo web statistics

# Requirements

## Requirements for local development (Docker setup)

* [Docker Compose](https://docs.docker.com/compose/)
* The images have been developed for the amd64 architecture

# Local development in containers (Docker)

If you use Windows, ensure that core.autocrlf is set to false in your git client before you clone the matomo-ansible
repository: _git config --global core.autocrlf false_ Otherwise the Docker images may not work due to line
ending changes.

### Building the images

If you want to test any local updates, you need to re-build the images:

```
cd docker
./build-local-images.sh
```

### Running the application using Docker

First add an entry to your `/etc/hosts` file (or equivalent) so that queries for the development setup
interface resolve to your loopback interface. For example:

```
127.0.0.1 www.matomo.test
```

Unless you want to build the images locally (see above), you need to pull them from the registry:

```
cd docker
docker compose pull
```

Then start the Docker Compose setup:
```
docker compose up
```

Then wait until Matomo has started. This may take a couple of minutes. Navigate to
https://www.matomo.test in your browser. The development setup runs with
self-signed certificates, so you'll need to accept the security warning in your browser.

Run the setup wizard to configure Matomo

## License

This project is licensed under the MIT license.
The full license can be found in [LICENSE](LICENSE).

