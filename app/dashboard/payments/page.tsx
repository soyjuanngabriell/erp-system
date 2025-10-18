"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { useToast } from "@/hooks/use-toast"
import { Plus, DollarSign, Receipt } from "lucide-react"

interface Order {
  id: string
  order_number: string
  customer_name: string
  customer_rnc: string | null
  status: string
  total: number
  payment_amount: number
  pending_amount: number
  created_at: string
  invoice_id: string | null
}

interface Payment {
  id: string
  amount: number
  payment_method: string
  payment_date: string
  notes: string | null
}

export default function PaymentManagementPage() {
  const { toast } = useToast()
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null)
  const [payments, setPayments] = useState<Payment[]>([])
  const [isPaymentDialogOpen, setIsPaymentDialogOpen] = useState(false)
  const [isProcessingPayment, setIsProcessingPayment] = useState(false)
  
  const [paymentAmount, setPaymentAmount] = useState(0)
  const [paymentMethod, setPaymentMethod] = useState("Efectivo")
  const [paymentNotes, setPaymentNotes] = useState("")

  useEffect(() => {
    fetchOrders()
  }, [])

  const fetchOrders = async () => {
    try {
      const supabase = createClient()
      const { data, error } = await supabase
        .from("orders")
        .select("*")
        .in("status", ["Pendiente", "En Proceso", "Completado"])
        .order("created_at", { ascending: false })

      if (error) throw error
      setOrders(data || [])
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al cargar las órdenes",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  const fetchPayments = async (orderId: string) => {
    try {
      const supabase = createClient()
      const { data, error } = await supabase
        .from("payments")
        .select("*")
        .eq("order_id", orderId)
        .order("payment_date", { ascending: false })

      if (error) throw error
      setPayments(data || [])
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al cargar los pagos",
        variant: "destructive",
      })
    }
  }

  const handleOrderSelect = (order: Order) => {
    setSelectedOrder(order)
    fetchPayments(order.id)
  }

  const handleAddPayment = async () => {
    if (!selectedOrder || paymentAmount <= 0) return

    setIsProcessingPayment(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) throw new Error("No autenticado")

      // Add payment
      const { error: paymentError } = await supabase.from("payments").insert({
        order_id: selectedOrder.id,
        amount: paymentAmount,
        payment_method: paymentMethod,
        notes: paymentNotes || null,
        created_by: user.id,
      })

      if (paymentError) throw paymentError

      // Update order payment amount
      const newPaymentAmount = selectedOrder.payment_amount + paymentAmount
      const newPendingAmount = selectedOrder.total - newPaymentAmount

      const { error: orderError } = await supabase
        .from("orders")
        .update({
          payment_amount: newPaymentAmount,
          pending_amount: newPendingAmount,
          updated_at: new Date().toISOString(),
        })
        .eq("id", selectedOrder.id)

      if (orderError) throw orderError

      toast({
        title: "Pago registrado",
        description: `Pago de RD$ ${paymentAmount.toLocaleString()} registrado exitosamente`,
      })

      // Reset form and refresh data
      setPaymentAmount(0)
      setPaymentNotes("")
      setIsPaymentDialogOpen(false)
      fetchOrders()
      if (selectedOrder) {
        fetchPayments(selectedOrder.id)
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al registrar el pago",
        variant: "destructive",
      })
    } finally {
      setIsProcessingPayment(false)
    }
  }

  const handleConvertToInvoice = async (order: Order) => {
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) throw new Error("No autenticado")

      // Convert order to invoice
      const { data: invoiceId, error } = await supabase.rpc("convert_order_to_invoice", {
        p_order_id: order.id,
        p_invoice_type: "BASICA"
      })

      if (error) throw error

      toast({
        title: "Orden convertida",
        description: "La orden ha sido convertida a factura exitosamente",
      })

      fetchOrders()
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al convertir la orden a factura",
        variant: "destructive",
      })
    }
  }

  const getStatusBadge = (status: string) => {
    const variants = {
      "Pendiente": "secondary",
      "En Proceso": "default",
      "Completado": "default",
      "Facturada": "success",
      "Cancelado": "destructive"
    } as const

    return (
      <Badge variant={variants[status as keyof typeof variants] || "secondary"}>
        {status}
      </Badge>
    )
  }

  if (isLoading) {
    return <div className="p-6">Cargando...</div>
  }

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Gestión de Pagos</h1>
        <p className="text-muted-foreground">Administra los pagos de las órdenes pendientes</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Orders List */}
        <Card>
          <CardHeader>
            <CardTitle>Órdenes Pendientes</CardTitle>
            <CardDescription>
              Órdenes que requieren gestión de pagos
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {orders.map((order) => (
                <div
                  key={order.id}
                  className={`p-4 border rounded-lg cursor-pointer transition-colors ${
                    selectedOrder?.id === order.id ? "bg-muted" : "hover:bg-muted/50"
                  }`}
                  onClick={() => handleOrderSelect(order)}
                >
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="font-semibold">{order.order_number}</h3>
                      <p className="text-sm text-muted-foreground">{order.customer_name}</p>
                      <p className="text-sm text-muted-foreground">
                        {order.customer_rnc && `RNC: ${order.customer_rnc}`}
                      </p>
                    </div>
                    <div className="text-right">
                      {getStatusBadge(order.status)}
                      <p className="text-sm font-medium">RD$ {order.total.toLocaleString()}</p>
                      <p className="text-sm text-red-600">
                        Pendiente: RD$ {order.pending_amount.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Order Details and Payments */}
        <Card>
          <CardHeader>
            <CardTitle>
              {selectedOrder ? `Orden ${selectedOrder.order_number}` : "Selecciona una Orden"}
            </CardTitle>
            <CardDescription>
              {selectedOrder ? "Detalles y gestión de pagos" : "Selecciona una orden para ver los detalles"}
            </CardDescription>
          </CardHeader>
          <CardContent>
            {selectedOrder ? (
              <div className="space-y-4">
                {/* Order Summary */}
                <div className="grid grid-cols-2 gap-4 p-4 bg-muted rounded-lg">
                  <div>
                    <p className="text-sm text-muted-foreground">Total</p>
                    <p className="font-semibold">RD$ {selectedOrder.total.toLocaleString()}</p>
                  </div>
                  <div>
                    <p className="text-sm text-muted-foreground">Pagado</p>
                    <p className="font-semibold text-green-600">
                      RD$ {selectedOrder.payment_amount.toLocaleString()}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-muted-foreground">Pendiente</p>
                    <p className="font-semibold text-red-600">
                      RD$ {selectedOrder.pending_amount.toLocaleString()}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-muted-foreground">Estado</p>
                    {getStatusBadge(selectedOrder.status)}
                  </div>
                </div>

                {/* Payment Actions */}
                <div className="flex gap-2">
                  <Dialog open={isPaymentDialogOpen} onOpenChange={setIsPaymentDialogOpen}>
                    <DialogTrigger asChild>
                      <Button size="sm" disabled={selectedOrder.pending_amount <= 0}>
                        <Plus className="h-4 w-4 mr-2" />
                        Agregar Pago
                      </Button>
                    </DialogTrigger>
                    <DialogContent>
                      <DialogHeader>
                        <DialogTitle>Registrar Pago</DialogTitle>
                      </DialogHeader>
                      <div className="space-y-4">
                        <div className="space-y-2">
                          <Label htmlFor="paymentAmount">Monto del Pago</Label>
                          <Input
                            id="paymentAmount"
                            type="number"
                            min="0.01"
                            max={selectedOrder.pending_amount}
                            step="0.01"
                            value={paymentAmount}
                            onChange={(e) => setPaymentAmount(parseFloat(e.target.value) || 0)}
                            placeholder="0.00"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="paymentMethod">Método de Pago</Label>
                          <Select value={paymentMethod} onValueChange={setPaymentMethod}>
                            <SelectTrigger>
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="Efectivo">Efectivo</SelectItem>
                              <SelectItem value="Tarjeta">Tarjeta</SelectItem>
                              <SelectItem value="Transferencia">Transferencia</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="paymentNotes">Notas (opcional)</Label>
                          <Textarea
                            id="paymentNotes"
                            value={paymentNotes}
                            onChange={(e) => setPaymentNotes(e.target.value)}
                            placeholder="Notas adicionales sobre el pago"
                          />
                        </div>
                        <div className="flex justify-end gap-2">
                          <Button
                            variant="outline"
                            onClick={() => setIsPaymentDialogOpen(false)}
                          >
                            Cancelar
                          </Button>
                          <Button
                            onClick={handleAddPayment}
                            disabled={isProcessingPayment || paymentAmount <= 0}
                          >
                            {isProcessingPayment ? "Registrando..." : "Registrar Pago"}
                          </Button>
                        </div>
                      </div>
                    </DialogContent>
                  </Dialog>

                  {selectedOrder.status === "Completado" && selectedOrder.pending_amount <= 0 && (
                    <Button
                      size="sm"
                      onClick={() => handleConvertToInvoice(selectedOrder)}
                    >
                      <Receipt className="h-4 w-4 mr-2" />
                      Convertir a Factura
                    </Button>
                  )}
                </div>

                {/* Payment History */}
                <div>
                  <h4 className="font-semibold mb-2">Historial de Pagos</h4>
                  {payments.length > 0 ? (
                    <div className="space-y-2">
                      {payments.map((payment) => (
                        <div key={payment.id} className="flex justify-between items-center p-2 border rounded">
                          <div>
                            <p className="font-medium">RD$ {payment.amount.toLocaleString()}</p>
                            <p className="text-sm text-muted-foreground">
                              {payment.payment_method} - {new Date(payment.payment_date).toLocaleDateString()}
                            </p>
                            {payment.notes && (
                              <p className="text-sm text-muted-foreground">{payment.notes}</p>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-sm text-muted-foreground">No hay pagos registrados</p>
                  )}
                </div>
              </div>
            ) : (
              <p className="text-muted-foreground text-center py-8">
                Selecciona una orden para ver los detalles y gestionar los pagos
              </p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
