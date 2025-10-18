import { createClient } from "@/lib/supabase/server"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { ArrowLeft, Edit } from "lucide-react"
import Link from "next/link"
import { notFound } from "next/navigation"

interface Order {
  id: string
  order_number: string
  customer_name: string
  customer_email?: string
  customer_phone?: string
  status: string
  total: number
  subtotal: number
  tax: number
  discount: number
  notes?: string
  created_at: string
  deposit_amount?: number
  payment_amount?: number
  pending_amount?: number
  payment_status?: string
  order_items: Array<{
    id: string
    product_name: string
    product_sku: string
    quantity: number
    unit_price: number
    subtotal: number
  }>
}

export default async function OrderDetailPage({ 
  params 
}: { 
  params: Promise<{ id: string }> 
}) {
  const { id } = await params
  const supabase = await createClient()

  const { data: order } = await supabase
    .from("orders")
    .select(`
      *,
      order_items (*),
      created_by_profile:profiles!orders_created_by_fkey(full_name, email),
      assigned_to_profile:profiles!orders_assigned_to_fkey(full_name, email)
    `)
    .eq("id", id)
    .single()

  if (!order) {
    notFound()
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "Completado":
        return "bg-green-500/10 text-green-500 hover:bg-green-500/20"
      case "En Proceso":
        return "bg-blue-500/10 text-blue-500 hover:bg-blue-500/20"
      case "Pendiente":
        return "bg-yellow-500/10 text-yellow-500 hover:bg-yellow-500/20"
      case "Cancelado":
        return "bg-red-500/10 text-red-500 hover:bg-red-500/20"
      default:
        return ""
    }
  }

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
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/orders">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold">Orden #{order.order_number}</h1>
            <p className="text-muted-foreground">Detalles de la orden</p>
          </div>
        </div>
        <Button asChild>
          <Link href={`/dashboard/orders/${order.id}/edit`}>
            <Edit className="mr-2 h-4 w-4" />
            Editar Orden
          </Link>
        </Button>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Order Information */}
        <Card>
          <CardHeader>
            <CardTitle>Información de la Orden</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-sm font-medium text-muted-foreground">Número de Orden</p>
                <p className="text-lg font-semibold">#{order.order_number}</p>
              </div>
              <div>
                <p className="text-sm font-medium text-muted-foreground">Estado</p>
                <Badge variant="secondary" className={getStatusColor(order.status)}>
                  {order.status}
                </Badge>
              </div>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Fecha de Creación</p>
              <p>{new Date(order.created_at).toLocaleDateString("es-DO", {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
              })}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Creado por</p>
              <p>{order.created_by_profile?.full_name || 'N/A'}</p>
            </div>
            {order.assigned_to_profile && (
              <div>
                <p className="text-sm font-medium text-muted-foreground">Asignado a</p>
                <p>{order.assigned_to_profile.full_name}</p>
                {order.assigned_at && (
                  <p className="text-xs text-muted-foreground">
                    Asignado el {new Date(order.assigned_at).toLocaleDateString("es-DO")}
                  </p>
                )}
              </div>
            )}
            {order.notes && (
              <div>
                <p className="text-sm font-medium text-muted-foreground">Notas</p>
                <p className="text-sm">{order.notes}</p>
              </div>
            )}
            {order.deposit_amount && order.deposit_amount > 0 && (
              <div>
                <p className="text-sm font-medium text-muted-foreground">Abono Recibido</p>
                <p className="text-sm">RD$ {order.deposit_amount.toLocaleString()}</p>
                {order.payment_status === "partial" && (
                  <p className="text-xs text-muted-foreground">
                    Pendiente: RD$ {(order.total - order.deposit_amount).toLocaleString()}
                  </p>
                )}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Customer Information */}
        <Card>
          <CardHeader>
            <CardTitle>Información del Cliente</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Nombre</p>
              <p className="text-lg font-semibold">{order.customer_name}</p>
            </div>
            {order.customer_email && (
              <div>
                <p className="text-sm font-medium text-muted-foreground">Email</p>
                <p>{order.customer_email}</p>
              </div>
            )}
            {order.customer_phone && (
              <div>
                <p className="text-sm font-medium text-muted-foreground">Teléfono</p>
                <p>{order.customer_phone}</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Order Items */}
      <Card>
        <CardHeader>
          <CardTitle>Productos</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {order.order_items?.map((item: any) => (
              <div key={item.id} className="flex justify-between items-center p-4 border rounded-lg">
                <div className="flex-1">
                  <h4 className="font-medium">{item.product_name}</h4>
                  <p className="text-sm text-muted-foreground">
                    Cantidad: {item.quantity} × {formatCurrency(item.unit_price || 0)}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-semibold">{formatCurrency(item.subtotal || 0)}</p>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Order Summary */}
      <Card>
        <CardHeader>
          <CardTitle>Resumen de la Orden</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span>Subtotal:</span>
              <span>{formatCurrency(order.subtotal)}</span>
            </div>
            {order.discount > 0 && (
              <div className="flex justify-between">
                <span>Descuento:</span>
                <span>-{formatCurrency(order.discount)}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span>Impuestos:</span>
              <span>{formatCurrency(order.tax)}</span>
            </div>
            <div className="flex justify-between text-lg font-semibold border-t pt-2">
              <span>Total:</span>
              <span>{formatCurrency(order.total)}</span>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
