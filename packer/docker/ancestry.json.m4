m4_changequote(`[[[', `]]]')m4_dnl
m4_define([[[repository]]], [[[precisely/ancestry]]])m4_dnl
m4_ifelse(mode, [[[link]]], [[[m4_dnl
m4_define([[[repository]]], [[[precisely/ancestry-link]]])m4_dnl
]]])m4_dnl
{
  "builders": [{
    "type": "docker",
    "image": "precisely/ubuntu-base:latest",
    "pull": false,
    "commit": true,
    "changes": [
m4_ifelse(mode, [[[link]]], [[[m4_dnl
      "VOLUME /app"
]]])m4_dnl
    ]
  }],
  "provisioners": [
    {
      "type": "ansible",
      "playbook_file": "../ansible/nodes/ancestry.yml"
    },
m4_ifelse(mode, [[[build]]], [[[m4_dnl
    {
      "type": "shell",
      "inline": [
        # FIXME: This needs to copy stuff.
        # Easiest way: locate dominating .git and take it from there?
        # Maybe Packer has a good way to copy things from the building system.
      ]
    },
]]])m4_dnl
    {
      "type": "shell",
      "inline": [
        "find / -type d -name '~*' | xargs rm -rf"
      ]
    }
  ],
  "post-processors": [
    {
      "type": "docker-tag",
      "[[[repository]]]": "repository",
      "tag": "latest"
    },
    {
      "type": "docker-tag",
      "[[[repository]]]": "repository",
      "tag": "{{isotime \"2006-01-02T150405\"}}"
    }
  ]
}
