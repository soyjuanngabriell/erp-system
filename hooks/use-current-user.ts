"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"

interface User {
  id: string
  full_name: string
  email: string
  role: string
}

export function useCurrentUser() {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)
  const supabase = createClient()

  useEffect(() => {
    async function fetchCurrentUser() {
      try {
        const { data: { user: authUser } } = await supabase.auth.getUser()
        
        if (!authUser) {
          setUser(null)
          return
        }

        const { data: profile, error } = await supabase
          .from("profiles")
          .select("id, full_name, email, role")
          .eq("id", authUser.id)
          .single()

        if (error) {
          console.error("Error fetching user profile:", error)
          return
        }

        setUser(profile)
      } catch (error) {
        console.error("Error:", error)
      } finally {
        setLoading(false)
      }
    }

    fetchCurrentUser()
  }, [supabase])

  return { user, loading }
}
