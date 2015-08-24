db.createUser(
  {
    user: "siteUserAdmin",
    pwd: "{{ mongo_admin_pwd }}",
    roles: [
       { role: "dbAdminAnyDatabase", db: "admin" },
       { role: "readWriteAnyDatabase", db: "admin" },
       { role: "clusterAdmin", db: "admin" }
    ]
  }
)
