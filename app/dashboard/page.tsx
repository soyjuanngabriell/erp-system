import { createClient } from "@/lib/supabase/server"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { ShoppingCart, FileText, Package, TrendingUp, AlertTriangle } from "lucide-react"
import { AssignedOrdersSection } from "@/components/assigned-orders-section"
import { getAllActiveProducts, getLowStockProducts, getStockStatistics } from "@/lib/utils/stock-utils"

export default async function DashboardPage() {
  const supabase = await createClient()

  // Get statistics
  const { count: ordersCount } = await supabase.from("orders").select("*", { count: "exact", head: true })

  const { count: invoicesCount } = await supabase.from("invoices").select("*", { count: "exact", head: true })

  const { count: productsCount } = await supabase.from("products").select("*", { count: "exact", head: true })

  // Get all active products and calculate stock statistics
  const allProducts = await getAllActiveProducts()
  const stockStats = getStockStatistics(allProducts)
  const lowStockProducts = stockStats.lowStockProducts

  const { data: recentOrders } = await supabase
    .from("orders")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(5)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Dashboard</h1>
        <p className="text-muted-foreground">Resumen general del sistema</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Órdenes</CardTitle>
            <ShoppingCart className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{ordersCount || 0}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Facturas</CardTitle>
            <FileText className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{invoicesCount || 0}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Productos</CardTitle>
            <Package className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{productsCount || 0}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Stock Bajo</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{lowStockProducts?.length || 0}</div>
          </CardContent>
        </Card>
      </div>

      {/* Assigned Orders Section */}
      <AssignedOrdersSection />

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Órdenes Recientes</CardTitle>
          </CardHeader>
          <CardContent>
            {recentOrders && recentOrders.length > 0 ? (
              <div className="space-y-4">
                {recentOrders.map((order) => (
                  <div key={order.id} className="flex items-center justify-between border-b pb-2 last:border-0">
                    <div>
                      <p className="font-medium">{order.order_number}</p>
                      <p className="text-sm text-muted-foreground">{order.customer_name}</p>
                    </div>
                    <div className="text-right">
                      <p className="font-medium">RD$ {order.total.toLocaleString()}</p>
                      <p className="text-sm text-muted-foreground">{order.status}</p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">No hay órdenes recientes</p>
            )}
          </CardContent>
        </Card>

        <Card className={lowStockProducts.length > 0 ? "border-destructive" : ""}>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              {lowStockProducts.length > 0 && <AlertTriangle className="h-5 w-5 text-destructive" />}
              Productos con Stock Bajo
              {lowStockProducts.length > 0 && (
                <span className="ml-auto text-sm font-normal text-destructive">
                  {lowStockProducts.length} producto{lowStockProducts.length !== 1 ? 's' : ''}
                </span>
              )}
            </CardTitle>
          </CardHeader>
          <CardContent>
            {lowStockProducts.length > 0 ? (
              <div className="space-y-4">
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
                        Mín: {product.min_stock} | 
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
                  <p className="text-sm text-muted-foreground text-center">
                    Y {lowStockProducts.length - 5} producto{lowStockProducts.length - 5 !== 1 ? 's' : ''} más...
                  </p>
                )}
              </div>
            ) : (
              <div className="text-center py-4">
                <Package className="h-12 w-12 text-muted-foreground mx-auto mb-2" />
                <p className="text-sm text-muted-foreground">No hay productos con stock bajo</p>
                <p className="text-xs text-muted-foreground mt-1">Todos los productos tienen stock suficiente</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
