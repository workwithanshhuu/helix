# deploy

| Path | Day | Content |
| --- | --- | --- |
| `docker-compose.yml` | 27 | 3 helix-meta + 3 helixd (+ Prometheus/Grafana on day 39) |
| `Dockerfile.meta`, `Dockerfile.worker` | 27, 29 | Images |
| `terraform/` | 41 | 1 large 2-socket VM + 2 small VMs for days 42–43; **always `terraform destroy` after** |
| `prometheus.yml`, `grafana/` | 39 | Scrape config and dashboard |

Never commit Terraform state or credentials.
