# Changelog
## v0.0.1-alpha

- Add docker compose port
- Improve install script
- Add base uninstall script (need deeper work)
- Add ttyd for systemd logging
## v0.0.1-rc (2022-08-18)

- Integrate BirdNET-Analyzer as submodule
- Add birdnet_recording service
- Add birdnet_analyzis service
- Create symfony webapp
- Extracts BirdNET bird contacts into SQL database
- Add birdnet_stream icecast audio streaming and live spectrogram service https://birdnet/spectro
- Add /today/species and /today/{date}/species/{id} endpoints
- Add records deletion button and /records/delete endpoint as well as bulk deletion (select all button on /today/species/{id} endpoint)
- Add systemd status page /status
- Add i18n for webapp (not species name), en|fr only for the moment