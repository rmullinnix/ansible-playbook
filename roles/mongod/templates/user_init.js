db.createUser(
  {
    user: "siteUserAdmin",
    pwd: "{{ mongo_admin_pwd }}",
    roles: [
       { role: "userAdminAnyDatabase", db: "admin" },
       { role: "readWrite", db: "admin" },
       { role: "clusterAdmin", db: "admin" }
    ]
  }
)
