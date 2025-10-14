import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { SalesChart } from "@/components/sales-chart"
import { TopProductsChart } from "@/components/top-products-chart"
import { DollarSign, TrendingUp, ShoppingCart, Package } from "lucide-react"

export default async function ReportsPage() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user?.id).single()

  if (profile?.role !== "Admin") {
    redirect("/dashboard")
  }

  // Get current month dates
  const now = new Date()
  const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
  const lastDayOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0)

  // Sales statistics
  const { data: invoices } = await supabase
    .from("invoices")
    .select("total, created_at")
    .gte("created_at", firstDayOfMonth.toISOString())
    .lte("created_at", lastDayOfMonth.toISOString())

  const totalSales = invoices?.reduce((sum, inv) => sum + inv.total, 0) || 0
  const salesCount = invoices?.length || 0

  // Orders statistics
  const { count: ordersCount } = await supabase
    .from("orders")
    .select("*", { count: "exact", head: true })
    .gte("created_at", firstDayOfMonth.toISOString())
    .lte("created_at", lastDayOfMonth.toISOString())

  // Products statistics
  const { data: products } = await supabase.from("products").select("stock, cost")

  const inventoryValue = products?.reduce((sum, prod) => sum + prod.stock * prod.cost, 0) || 0

  // Get sales by day for chart
  const { data: dailySales } = await supabase
    .from("invoices")
    .select("total, created_at")
    .gte("created_at", firstDayOfMonth.toISOString())
    .lte("created_at", lastDayOfMonth.toISOString())
    .order("created_at")

  // Get top selling products
  const { data: topProducts } = await supabase
    .from("invoice_items")
    .select(
      `
      product_name,
      quantity,
      subtotal
    `,
    )
    .gte("created_at", firstDayOfMonth.toISOString())
    .lte("created_at", lastDayOfMonth.toISOString())

  // Aggregate top products
  const productSales = new Map<string, { quantity: number; revenue: number }>()
  topProducts?.forEach((item) => {
    const existing = productSales.get(item.product_name) || { quantity: 0, revenue: 0 }
    productSales.set(item.product_name, {
      quantity: existing.quantity + item.quantity,
      revenue: existing.revenue + item.subtotal,
    })
  })

  const topProductsData = Array.from(productSales.entries())
    .map(([name, data]) => ({ name, ...data }))
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 10)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Reportes y Análisis</h1>
        <p className="text-muted-foreground">Visualiza el rendimiento de tu negocio</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Ventas del Mes</CardTitle>
            <DollarSign className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">RD$ {totalSales.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">{salesCount} facturas emitidas</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Órdenes del Mes</CardTitle>
            <ShoppingCart className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{ordersCount || 0}</div>
            <p className="text-xs text-muted-foreground">Órdenes procesadas</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Valor del Inventario</CardTitle>
            <Package className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">RD$ {inventoryValue.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">Valor total en stock</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Ticket Promedio</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              RD$ {salesCount > 0 ? (totalSales / salesCount).toLocaleString() : 0}
            </div>
            <p className="text-xs text-muted-foreground">Promedio por factura</p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="sales" className="space-y-4">
        <TabsList>
          <TabsTrigger value="sales">Ventas</TabsTrigger>
          <TabsTrigger value="products">Productos</TabsTrigger>
          <TabsTrigger value="customers">Clientes</TabsTrigger>
        </TabsList>

        <TabsContent value="sales" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Ventas Diarias</CardTitle>
              <CardDescription>Ventas del mes actual por día</CardDescription>
            </CardHeader>
            <CardContent>
              <SalesChart data={dailySales || []} />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="products" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Productos Más Vendidos</CardTitle>
              <CardDescription>Top 10 productos por ingresos del mes</CardDescription>
            </CardHeader>
            <CardContent>
              <TopProductsChart data={topProductsData} />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="customers" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Análisis de Clientes</CardTitle>
              <CardDescription>Próximamente</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Esta sección estará disponible próximamente con análisis detallado de clientes.
              </p>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}
