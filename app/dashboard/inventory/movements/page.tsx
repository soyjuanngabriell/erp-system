import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Plus, ArrowLeft } from "lucide-react"
import Link from "next/link"
import { StockMovementsTable } from "@/components/stock-movements-table"

export default async function StockMovementsPage() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user?.id).single()

  if (profile?.role !== "Admin") {
    redirect("/dashboard")
  }

  const { data: movements } = await supabase
    .from("stock_movements")
    .select(
      `
      *,
      products (name, sku)
    `,
    )
    .order("created_at", { ascending: false })
    .limit(100)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/inventory">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold">Movimientos de Stock</h1>
            <p className="text-muted-foreground">Historial de entradas y salidas de inventario</p>
          </div>
        </div>
        <Button asChild>
          <Link href="/dashboard/inventory/movements/new">
            <Plus className="mr-2 h-4 w-4" />
            Nuevo Movimiento
          </Link>
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Historial de Movimientos</CardTitle>
        </CardHeader>
        <CardContent>
          <StockMovementsTable movements={movements || []} />
        </CardContent>
      </Card>
    </div>
  )
}
