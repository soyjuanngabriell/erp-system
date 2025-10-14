import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { StockMovementForm } from "@/components/stock-movement-form"

export default async function NewStockMovementPage() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user?.id).single()

  if (profile?.role !== "Admin") {
    redirect("/dashboard")
  }

  const { data: products } = await supabase.from("products").select("*").eq("is_active", true).order("name")

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Nuevo Movimiento de Stock</h1>
        <p className="text-muted-foreground">Registra una entrada, salida o ajuste de inventario</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Información del Movimiento</CardTitle>
        </CardHeader>
        <CardContent>
          <StockMovementForm products={products || []} />
        </CardContent>
      </Card>
    </div>
  )
}
