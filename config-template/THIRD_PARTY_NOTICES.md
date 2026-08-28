# Third-Party Configuration

The bootstrap installs selected configuration from pinned Git submodules:

- Addy Osmani Agent Skills, MIT, `vendor/addy-agent-skills`
- Cloudflare Agent Skills, Apache-2.0, `vendor/cloudflare-skills` and `vendor/cloudflare-turnstile-spin`
- Payload Agent Skills, subject to the upstream repository's terms, `vendor/payload-skills`
- Ponytail, MIT, `vendor/ponytail`

The submodule Git links pin the exact upstream commits. Available license files remain in each submodule and bootstrap copies the applicable notices with the installed configuration. The complete Addy MIT notice is also tracked at `licenses/ADDY_AGENT_SKILLS_LICENSE`; locally adapted Addy skills retain their source and pinned commit in `skills/ADDY_AGENT_SKILLS.md`.
