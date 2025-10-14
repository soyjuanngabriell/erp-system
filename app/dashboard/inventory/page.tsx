import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Plus } from "lucide-react"
import Link from "next/link"
import { ProductsTable } from "@/components/products-table"

export default async function InventoryPage() {
  const supabase = await createClient()

  // Check if user is admin
  const {
    data: { user },
  } = await supabase.auth.getUser()
  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user?.id).single()

  if (profile?.role !== "Admin") {
    redirect("/dashboard")
  }

  const { data: products } = await supabase.from("products").select("*").order("name")

  const { data: lowStockProducts } = await supabase
    .from("products")
    .select("*")
    .lte("stock", supabase.raw("min_stock"))
    .eq("is_active", true)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Inventario</h1>
          <p className="text-muted-foreground">Gestiona los productos y el stock</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" asChild>
            <Link href="/dashboard/inventory/movements">Ver Movimientos</Link>
          </Button>
          <Button asChild>
            <Link href="/dashboard/inventory/new">
              <Plus className="mr-2 h-4 w-4" />
              Nuevo Producto
            </Link>
          </Button>
        </div>
      </div>

      {lowStockProducts && lowStockProducts.length > 0 && (
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="text-destructive">Alerta de Stock Bajo</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground mb-4">
              Hay {lowStockProducts.length} producto(s) con stock por debajo del mínimo
            </p>
            <div className="space-y-2">
              {lowStockProducts.slice(0, 5).map((product) => (
                <div key={product.id} className="flex items-center justify-between border-b pb-2 last:border-0">
                  <div>
                    <p className="font-medium">{product.name}</p>
                    <p className="text-sm text-muted-foreground">{product.sku}</p>
                  </div>
                  <div className="text-right">
                    <p className="font-medium text-destructive">{product.stock} unidades</p>
                    <p className="text-sm text-muted-foreground">Mínimo: {product.min_stock}</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Lista de Productos</CardTitle>
        </CardHeader>
        <CardContent>
          <ProductsTable products={products || []} />
        </CardContent>
      </Card>
    </div>
  )
}
