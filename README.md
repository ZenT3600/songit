# songit
> a backup utility designed with music libraries in mind
> ![](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=for-the-badge&logo=GNU%20Bash&logoColor=white)

---

**songit** is an utility designed to shorten the backup times of large music libraries by taking advantage of `git` and `exiftool`.

the usage is quite simple, just:

```bash
./songit.sh /path/to/music/library /path/to/backup/folder
```

the program will handle the rest.

by adding the music's **metadata**, instead of the actual files, to a git repo, songit can significantly lower the wait times of backups after the first one.
