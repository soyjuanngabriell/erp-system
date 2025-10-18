import { createClient } from "@/lib/supabase/server"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { CheckCircle, Clock, DollarSign } from "lucide-react"
import Link from "next/link"

export default async function BillingPage() {
  const supabase = await createClient()

  // Get completed orders that are fully paid
  const { data: paidOrders } = await supabase
    .from("orders")
    .select(`
      *,
      order_items (*),
      created_by_profile:profiles!orders_created_by_fkey(full_name),
      assigned_to_profile:profiles!orders_assigned_to_fkey(full_name)
    `)
    .eq("status", "Completado")
    .eq("pending_amount", 0)
    .order("created_at", { ascending: false })

  // Get completed orders that are partially paid
  const { data: partialOrders } = await supabase
    .from("orders")
    .select(`
      *,
      order_items (*),
      created_by_profile:profiles!orders_created_by_fkey(full_name),
      assigned_to_profile:profiles!orders_assigned_to_fkey(full_name)
    `)
    .eq("status", "Completado")
    .gt("pending_amount", 0)
    .order("created_at", { ascending: false })

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('es-DO', {
      style: 'currency',
      currency: 'DOP',
      minimumFractionDigits: 2
    }).format(amount)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Facturación</h1>
          <p className="text-muted-foreground">Gestión de órdenes completadas</p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Paid Orders */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CheckCircle className="h-5 w-5 text-green-500" />
              Órdenes Pagadas Completamente
              <Badge variant="secondary" className="ml-auto">
                {paidOrders?.length || 0}
              </Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            {paidOrders && paidOrders.length > 0 ? (
              <div className="rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Orden</TableHead>
                      <TableHead>Cliente</TableHead>
                      <TableHead>Asignado a</TableHead>
                      <TableHead className="text-right">Total</TableHead>
                      <TableHead className="text-right">Acciones</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {paidOrders.map((order) => (
                      <TableRow key={order.id}>
                        <TableCell className="font-medium">{order.order_number}</TableCell>
                        <TableCell>{order.customer_name}</TableCell>
                        <TableCell>{order.assigned_to_profile?.full_name || 'N/A'}</TableCell>
                        <TableCell className="text-right">{formatCurrency(order.total)}</TableCell>
                        <TableCell className="text-right">
                          <Button variant="outline" size="sm" asChild>
                            <Link href={`/dashboard/orders/${order.id}`}>
                              Ver Detalles
                            </Link>
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            ) : (
              <p className="text-center text-muted-foreground py-8">
                No hay órdenes pagadas completamente
              </p>
            )}
          </CardContent>
        </Card>

        {/* Partially Paid Orders */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Clock className="h-5 w-5 text-yellow-500" />
              Órdenes con Abono Parcial
              <Badge variant="secondary" className="ml-auto">
                {partialOrders?.length || 0}
              </Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            {partialOrders && partialOrders.length > 0 ? (
              <div className="rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Orden</TableHead>
                      <TableHead>Cliente</TableHead>
                      <TableHead>Asignado a</TableHead>
                      <TableHead className="text-right">Abono</TableHead>
                      <TableHead className="text-right">Pendiente</TableHead>
                      <TableHead className="text-right">Acciones</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {partialOrders.map((order) => (
                      <TableRow key={order.id}>
                        <TableCell className="font-medium">{order.order_number}</TableCell>
                        <TableCell>{order.customer_name}</TableCell>
                        <TableCell>{order.assigned_to_profile?.full_name || 'N/A'}</TableCell>
                        <TableCell className="text-right">{formatCurrency(order.deposit_amount || 0)}</TableCell>
                        <TableCell className="text-right">
                          {formatCurrency(order.total - (order.deposit_amount || 0))}
                        </TableCell>
                        <TableCell className="text-right">
                          <div className="flex gap-2 justify-end">
                            <Button variant="outline" size="sm" asChild>
                              <Link href={`/dashboard/orders/${order.id}`}>
                                Ver
                              </Link>
                            </Button>
                            <Button variant="default" size="sm" asChild>
                              <Link href={`/dashboard/billing/${order.id}/mark-paid`}>
                                <DollarSign className="mr-1 h-4 w-4" />
                                Marcar Pagado
                              </Link>
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            ) : (
              <p className="text-center text-muted-foreground py-8">
                No hay órdenes con abono parcial
              </p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
