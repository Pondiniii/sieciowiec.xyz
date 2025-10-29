---
description: Run comprehensive VPS maintenance - Docker updates, health checks, security monitoring, and documentation
---

Launch the vps-maintainer agent to perform comprehensive server maintenance.

Execute the following tasks:
1. Read context from docs/MEMORY.md
2. Update all Docker containers to latest versions
3. Verify all services are running correctly
4. Check system resources (disk, CPU, memory)
5. Analyze security logs for suspicious activity
6. Update documentation (raports, MEMORY.md)
7. Create or update Claude Code Skills in .claude/skills/ when you learn new patterns
8. Update README.md if infrastructure changed
9. Commit and push changes with appropriate status message

Focus on:
- System health and stability
- Security monitoring
- Automated problem resolution where possible
- Clear documentation of any issues requiring manual intervention

If everything is healthy, provide a brief summary. If issues are found, provide detailed actionable information.
