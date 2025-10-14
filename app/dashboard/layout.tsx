import type React from "react"
import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"
import { DashboardNav } from "@/components/dashboard-nav"
import { DashboardHeader } from "@/components/dashboard-header"

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    redirect("/auth/login")
  }

  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user.id).single()

  return (
    <div className="flex min-h-screen flex-col">
      <DashboardHeader profile={profile} />
      <div className="flex flex-1">
        <DashboardNav profile={profile} />
        <main className="flex-1 overflow-y-auto bg-muted/40 p-6">{children}</main>
      </div>
    </div>
  )
}
