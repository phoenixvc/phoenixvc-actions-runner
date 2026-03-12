# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**phoenixvc-actions-runner** — Self-hosted GitHub Actions runner infrastructure for the **phoenixvc** org and **JustAGhosT** personal account. Ephemeral VMSS runners for phoenixvc, persistent runner for JustAGhosT, shared listener VM on Azure.

## Tech Stack

- **Infrastructure**: Azure VMSS (Virtual Machine Scale Sets)
- **CI/CD**: GitHub Actions (self-hosted runners)
- **Scripts**: PowerShell/Bash for runner provisioning

## Architecture

Two runner configurations:
- **phoenixvc org** — Ephemeral VMSS-based runners (scale to zero)
- **JustAGhosT personal** — Persistent single runner
- **Shared** — Listener VM on Azure that coordinates both

## AgentKit Forge

This project has not yet been onboarded to [AgentKit Forge](https://github.com/phoenixvc/agentkit-forge). To request onboarding, [create a ticket](https://github.com/phoenixvc/agentkit-forge/issues/new?title=Onboard+phoenixvc-actions-runner&labels=onboarding).
