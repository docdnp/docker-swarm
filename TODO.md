# TODOs

* [ ] **Vagrant:** Replace docker-machine with vagrant for swarm setup
  * Reasoning: 
    * docker-machine isn't supported anymore
    * docker-machine provides only old docker distributions
* [ ] **Refactor / Vagrant:** Refactor helper functions to support vagrant
* [ ] **Refactor / Vagrant:** Modify README regarding vagrant
* [ ] **Refactor / Vagrant:** Introduce feature toggle as long as vagrant cannot be used in the same way as docker-machine
* [ ] **Docs:** Create analysis helper functions
* [ ] **Refactor / Compose:** Extract entryscript from swarm-launchers and mount it as config
* [ ] **Refactor / Compose:** Extract entryscript from swarm-launchers and mount it as config
* [ ] **Security / Compoes:** Remove docker.hub credentials from swarm compose files
* [ ] **Security / Compose:** Add credential files to .gitignore
* [ ] **Docs / Swarm Baics:** Describe basic concepts of swarm and how they relate to k8s
* [ ] **Docs / Helper:** Describe some useful helper functions right in the beginning of the README
* [ ] **Refactor / Scenarios:** Discard consul stuff at least from README until it is really useful
* [X] **Refactor:** Factor "private" helper functions out