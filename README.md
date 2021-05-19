# cc-docker
A configurable docker compose setup for easy deployment of ClusterCockpit

Desired modes:

* Demo: Includes everything to try out ClusterCockpit including initial Database Fixtures. No SSL and no reverse Proxy.
* Develop: Only includes all external components of ClusterCockpit. A functional PHP environment and the ClusterCockpit source must be maintained on host machine.
* Production: Includes everything to run ClusterCockpit in a Production environment including SSL and traefic reverse proxy and container orchestration.

 
