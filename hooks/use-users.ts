"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"

interface User {
  id: string
  full_name: string
  email: string
  role: string
}

export function useUsers() {
  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const supabase = createClient()

  useEffect(() => {
    async function fetchUsers() {
      try {
        const { data, error } = await supabase
          .from("profiles")
          .select("id, full_name, email, role")
          .order("full_name")

        if (error) {
          console.error("Error fetching users:", error)
          return
        }

        setUsers(data || [])
      } catch (error) {
        console.error("Error:", error)
      } finally {
        setLoading(false)
      }
    }

    fetchUsers()
  }, [supabase])

  return { users, loading }
}
