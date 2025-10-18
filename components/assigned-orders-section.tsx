"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Eye, CheckCircle, Clock, DollarSign } from "lucide-react"
import Link from "next/link"
import { useToast } from "@/hooks/use-toast"

interface AssignedOrder {
  id: string
  order_number: string
  customer_name: string
  customer_rnc: string | null
  status: string
  invoice_type: string
  total: number
  payment_amount: number
  pending_amount: number
  created_at: string
  assigned_at: string
}

export function AssignedOrdersSection() {
  const [orders, setOrders] = useState<AssignedOrder[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [completingOrder, setCompletingOrder] = useState<string | null>(null)
  const { toast } = useToast()

  useEffect(() => {
    fetchAssignedOrders()
  }, [])

  const fetchAssignedOrders = async () => {
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) return

      const { data, error } = await supabase
        .from("orders")
        .select("*")
        .eq("assigned_to", user.id)
        .in("status", ["Pendiente", "En Proceso"])
        .order("assigned_at", { ascending: false })
        .limit(5)

      if (error) throw error
      setOrders(data || [])
    } catch (error) {
      console.error("Error fetching assigned orders:", error)
      toast({
        title: "Error",
        description: "Error al cargar las órdenes asignadas",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  const handleCompleteOrder = async (orderId: string) => {
    try {
      setCompletingOrder(orderId)
      
      const supabase = createClient()
      
      // Update order status to completed
      const { error: updateError } = await supabase
        .from("orders")
        .update({
          status: "Completado",
          updated_at: new Date().toISOString()
        })
        .eq("id", orderId)

      if (updateError) throw updateError

      // Get the updated order to check payment status
      const { data: order, error: orderError } = await supabase
        .from("orders")
        .select("total, total_paid, pending_amount, invoice_type")
        .eq("id", orderId)
        .single()

      if (orderError) throw orderError

      // Calculate pending amount
      const pendingAmount = order.total - (order.total_paid || 0)

      // If order is fully paid, convert to invoice
      if (pendingAmount <= 0) {
        try {
          const { data: invoiceId, error: conversionError } = await supabase.rpc("convert_order_to_invoice", {
            p_order_id: orderId,
            p_invoice_type: order.invoice_type || "BASICA"
          })

          if (conversionError) {
            console.error("Error converting to invoice:", conversionError)
            toast({
              title: "Orden completada",
              description: "La orden ha sido completada exitosamente",
            })
          } else {
            toast({
              title: "Orden completada y convertida",
              description: "La orden ha sido completada y convertida a factura exitosamente",
            })
          }
        } catch (conversionError) {
          console.error("Error converting to invoice:", conversionError)
          toast({
            title: "Orden completada",
            description: "La orden ha sido completada exitosamente",
          })
        }
      } else {
        toast({
          title: "Orden completada",
          description: "La orden ha sido completada. Tiene saldo pendiente.",
        })
      }

      // Refresh the orders list
      fetchAssignedOrders()
    } catch (error) {
      console.error("Error completing order:", error)
      toast({
        title: "Error",
        description: "Error al completar la orden",
        variant: "destructive",
      })
    } finally {
      setCompletingOrder(null)
    }
  }

  const getStatusBadge = (status: string) => {
    const variants = {
      "Pendiente": "secondary",
      "En Proceso": "default",
      "Completado": "secondary",
      "Facturada": "secondary",
      "Cancelado": "destructive"
    } as const

    return (
      <Badge variant={variants[status as keyof typeof variants] || "secondary"}>
        {status}
      </Badge>
    )
  }

  const getInvoiceTypeLabel = (type: string) => {
    const labels = {
      "BASICA": "Básica",
      "VALOR_FISCAL": "Fiscal",
      "VALOR_GUBERNAMENTAL": "Gubernamental"
    } as const

    return labels[type as keyof typeof labels] || type
  }

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Clock className="h-5 w-5" />
            Mis Órdenes Asignadas
          </CardTitle>
          <CardDescription>
            Órdenes que has tomado y están pendientes
          </CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-center text-muted-foreground py-4">Cargando...</p>
        </CardContent>
      </Card>
    )
  }

  if (orders.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Clock className="h-5 w-5" />
            Mis Órdenes Asignadas
          </CardTitle>
          <CardDescription>
            Órdenes que has tomado y están pendientes
          </CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-center text-muted-foreground py-4">
            No tienes órdenes asignadas pendientes
          </p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Clock className="h-5 w-5" />
          Mis Órdenes Asignadas
        </CardTitle>
        <CardDescription>
          Órdenes que has tomado y están pendientes ({orders.length})
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {orders.map((order) => (
            <div
              key={order.id}
              className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors"
            >
              <div className="flex-1">
                <div className="flex items-center gap-3 mb-2">
                  <h3 className="font-semibold">{order.order_number}</h3>
                  {getStatusBadge(order.status)}
                  <Badge variant="outline" className="text-xs">
                    {getInvoiceTypeLabel(order.invoice_type)}
                  </Badge>
                </div>
                <p className="text-sm text-muted-foreground mb-1">
                  {order.customer_name}
                  {order.customer_rnc && ` • RNC: ${order.customer_rnc}`}
                </p>
                <div className="flex items-center gap-4 text-sm">
                  <span className="font-medium">RD$ {order.total.toLocaleString()}</span>
                  {order.pending_amount > 0 && (
                    <span className="text-red-600">
                      Pendiente: RD$ {order.pending_amount.toLocaleString()}
                    </span>
                  )}
                  <span className="text-muted-foreground">
                    Asignada: {new Date(order.assigned_at).toLocaleDateString("es-DO")}
                  </span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Button variant="ghost" size="icon" asChild>
                  <Link href={`/dashboard/orders/${order.id}`}>
                    <Eye className="h-4 w-4" />
                  </Link>
                </Button>
                {order.status !== "Completado" && (
                  <Button
                    size="sm"
                    onClick={() => handleCompleteOrder(order.id)}
                    disabled={completingOrder === order.id}
                    className="bg-green-600 hover:bg-green-700"
                  >
                    <CheckCircle className="h-4 w-4 mr-2" />
                    {completingOrder === order.id ? "Completando..." : "Completar"}
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
        <div className="mt-4 pt-4 border-t">
          <Button variant="outline" asChild className="w-full">
            <Link href="/dashboard/orders">
              Ver Todas las Órdenes
            </Link>
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
