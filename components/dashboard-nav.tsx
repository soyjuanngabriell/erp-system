"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { cn } from "@/lib/utils"
import { LayoutDashboard, ShoppingCart, FileText, Package, BarChart3, Settings, Receipt } from "lucide-react"

interface DashboardNavProps {
  profile: {
    role: "Admin" | "Vendedor"
  } | null
}

export function DashboardNav({ profile }: DashboardNavProps) {
  const pathname = usePathname()
  const isAdmin = profile?.role === "Admin"

  const routes = [
    {
      label: "Dashboard",
      icon: LayoutDashboard,
      href: "/dashboard",
      active: pathname === "/dashboard",
    },
    {
      label: "Órdenes",
      icon: ShoppingCart,
      href: "/dashboard/orders",
      active: pathname?.startsWith("/dashboard/orders"),
    },
    {
      label: "Facturación",
      icon: FileText,
      href: "/dashboard/invoices",
      active: pathname?.startsWith("/dashboard/invoices"),
    },
    {
      label: "Gestión de Pagos",
      icon: Receipt,
      href: "/dashboard/payments",
      active: pathname?.startsWith("/dashboard/payments"),
    },
    {
      label: "Inventario",
      icon: Package,
      href: "/dashboard/inventory",
      active: pathname?.startsWith("/dashboard/inventory"),
      adminOnly: true,
    },
    {
      label: "Reportes",
      icon: BarChart3,
      href: "/dashboard/reports",
      active: pathname?.startsWith("/dashboard/reports"),
      adminOnly: true,
    },
    {
      label: "Configuración",
      icon: Settings,
      href: "/dashboard/settings",
      active: pathname?.startsWith("/dashboard/settings"),
      adminOnly: true,
    },
  ]

  return (
    <nav className="w-64 border-r bg-background p-6">
      <div className="space-y-2">
        {routes.map((route) => {
          if (route.adminOnly && !isAdmin) return null

          return (
            <Link
              key={route.href}
              href={route.href}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors hover:bg-accent hover:text-accent-foreground",
                route.active ? "bg-accent text-accent-foreground" : "text-muted-foreground",
              )}
            >
              <route.icon className="h-4 w-4" />
              {route.label}
            </Link>
          )
        })}
      </div>
    </nav>
  )
}
