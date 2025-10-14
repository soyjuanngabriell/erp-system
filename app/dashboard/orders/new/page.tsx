import { createClient } from "@/lib/supabase/server"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { OrderForm } from "@/components/order-form"

export default async function NewOrderPage() {
  const supabase = await createClient()

  const { data: products } = await supabase.from("products").select("*").eq("is_active", true).order("name")

  const { data: customers } = await supabase.from("customers").select("*").order("name")

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Nueva Orden</h1>
        <p className="text-muted-foreground">Crea una nueva orden de venta</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Información de la Orden</CardTitle>
        </CardHeader>
        <CardContent>
          <OrderForm products={products || []} customers={customers || []} />
        </CardContent>
      </Card>
    </div>
  )
}
