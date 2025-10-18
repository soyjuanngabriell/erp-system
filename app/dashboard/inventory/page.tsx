import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Plus, AlertTriangle } from "lucide-react"
import Link from "next/link"
import { ProductsTable } from "@/components/products-table"
import { getAllActiveProducts, getLowStockProducts, getStockStatistics } from "@/lib/utils/stock-utils"

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

  // Get all active products and calculate stock statistics
  const allProducts = await getAllActiveProducts()
  const stockStats = getStockStatistics(allProducts)
  const lowStockProducts = stockStats.lowStockProducts

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

      {lowStockProducts.length > 0 && (
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-destructive">
              <AlertTriangle className="h-5 w-5" />
              Alerta de Stock Bajo
              <span className="ml-auto text-sm font-normal">
                {lowStockProducts.length} producto{lowStockProducts.length !== 1 ? 's' : ''}
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground mb-4">
              Hay {lowStockProducts.length} producto{lowStockProducts.length !== 1 ? 's' : ''} con stock por debajo del mínimo
            </p>
            <div className="space-y-2">
              {lowStockProducts.slice(0, 5).map((product) => (
                <div key={product.id} className="flex items-center justify-between border-b pb-2 last:border-0">
                  <div>
                    <p className="font-medium">{product.name}</p>
                    <p className="text-sm text-muted-foreground">{product.sku}</p>
                  </div>
                  <div className="text-right">
                    <p className={`font-medium ${
                      product.stock_status === 'critical' ? 'text-red-600' : 'text-orange-600'
                    }`}>
                      {product.stock} unidades
                    </p>
                    <p className="text-sm text-muted-foreground">
                      Mínimo: {product.min_stock} | 
                      <span className={`ml-1 ${
                        product.stock_status === 'critical' ? 'text-red-600' : 'text-orange-600'
                      }`}>
                        {product.stock_status === 'critical' ? 'CRÍTICO' : 'BAJO'}
                      </span>
                    </p>
                  </div>
                </div>
              ))}
              {lowStockProducts.length > 5 && (
                <p className="text-sm text-muted-foreground text-center pt-2">
                  Y {lowStockProducts.length - 5} producto{lowStockProducts.length - 5 !== 1 ? 's' : ''} más...
                </p>
              )}
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
