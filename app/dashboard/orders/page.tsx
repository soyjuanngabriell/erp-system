import { createClient } from "@/lib/supabase/server"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Plus } from "lucide-react"
import Link from "next/link"
import { OrdersTable } from "@/components/orders-table"

export default async function OrdersPage() {
  const supabase = await createClient()

  const { data: orders } = await supabase
    .from("orders")
    .select(
      `
      *,
      order_items (*)
    `,
    )
    .order("created_at", { ascending: false })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Órdenes</h1>
          <p className="text-muted-foreground">Gestiona las órdenes de venta</p>
        </div>
        <Button asChild>
          <Link href="/dashboard/orders/new">
            <Plus className="mr-2 h-4 w-4" />
            Nueva Orden
          </Link>
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Lista de Órdenes</CardTitle>
        </CardHeader>
        <CardContent>
          <OrdersTable orders={orders || []} />
        </CardContent>
      </Card>
    </div>
  )
}
