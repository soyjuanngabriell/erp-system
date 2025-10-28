"use client"

import type React from "react"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Plus, Trash2, Search, Save } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { type RncContributor, searchContributor } from "@/lib/utils/rnc-api"

interface Product {
  id: string
  name: string
  sku: string
  price: number
  stock: number
}

interface Customer {
  id: string
  name: string
  rnc_cedula: string | null
  email?: string | null
  phone?: string | null
}

interface OrderItem {
  product_id: string
  product_name: string
  product_sku: string
  quantity: number
  unit_price: number
  subtotal: number
}

interface OrderFormProps {
  products: Product[]
  customers: Customer[]
}

// Using RncContributor from rnc-api instead of local interface


export function OrderForm({ products, customers }: OrderFormProps) {
  const router = useRouter()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)

  const [customerId, setCustomerId] = useState("")
  const [customerName, setCustomerName] = useState("")
  const [customerRnc, setCustomerRnc] = useState("")
  const [customerEmail, setCustomerEmail] = useState("")
  const [customerPhone, setCustomerPhone] = useState("")
  const [status, setStatus] = useState<"Pendiente" | "Asignada" | "En Proceso" | "Completada" | "Facturada" | "Cancelada">("Pendiente")
  const [invoiceType, setInvoiceType] = useState<"BASICA" | "VALOR_FISCAL" | "VALOR_GUBERNAMENTAL">("BASICA")
  const [paymentMethod, setPaymentMethod] = useState<"Efectivo" | "Tarjeta" | "Transferencia" | "Cheque">("Efectivo")
  const [paymentAmount, setPaymentAmount] = useState(0)
  const [notes, setNotes] = useState("")
  const [items, setItems] = useState<OrderItem[]>([])

  const [selectedProduct, setSelectedProduct] = useState("")
  const [quantity, setQuantity] = useState(1)

  // RNC lookup state
  const [rncLookup, setRncLookup] = useState("")
  const [nameLookup, setNameLookup] = useState("")
  const [isLookingUp, setIsLookingUp] = useState(false)
  const [selectedSearchResult, setSelectedSearchResult] = useState<RncContributor | null>(null)
  const [isSavingCustomer, setIsSavingCustomer] = useState(false)

  const handleCustomerChange = (value: string) => {
    setCustomerId(value)
    const customer = customers.find((c) => c.id === value)
    if (customer) {
      setCustomerName(customer.name)
      setCustomerRnc(customer.rnc_cedula || "")
    }
  }

  const handleRncLookup = async () => {
    if (!rncLookup) return

    setIsLookingUp(true)
    try {
      const results = await searchContributor(rncLookup.trim())

      if (results && results.length > 0) {
        const contributor = results[0]
        setSelectedSearchResult(contributor)
        setCustomerName(contributor.commercial_name || contributor.social_reason || "")
        setCustomerRnc(contributor.rnc)
        setCustomerEmail(contributor.email || "")
        setCustomerPhone(contributor.phone || "")
        toast({
          title: "RNC encontrado",
          description: `Contribuyente: ${contributor.commercial_name || contributor.social_reason}`,
        })
      } else {
        toast({
          title: "RNC no encontrado",
          description: "No se encontró información para este RNC",
          variant: "destructive",
        })
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al consultar el RNC",
        variant: "destructive",
      })
    } finally {
      setIsLookingUp(false)
    }
  }

  const handleNameLookup = async () => {
    if (!nameLookup) return

    setIsLookingUp(true)
    try {
      const results = await searchContributor(nameLookup.trim())

      if (results && results.length > 0) {
        const contributor = results[0]
        setSelectedSearchResult(contributor)
        setCustomerName(contributor.commercial_name || contributor.social_reason || "")
        setCustomerRnc(contributor.rnc)
        setCustomerEmail(contributor.email || "")
        setCustomerPhone(contributor.phone || "")
        toast({
          title: "Contribuyente encontrado",
          description: `${contributor.commercial_name || contributor.social_reason}`,
        })
      } else {
        toast({
          title: "Contribuyente no encontrado",
          description: "No se encontró información para este nombre",
          variant: "destructive",
        })
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al consultar el contribuyente",
        variant: "destructive",
      })
    } finally {
      setIsLookingUp(false)
    }
  }

  const handleSaveCustomer = async () => {
    if (!selectedSearchResult) return

    setIsSavingCustomer(true)
    try {
      const response = await fetch("/api/customers", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: selectedSearchResult.commercial_name || selectedSearchResult.social_reason,
          rnc_cedula: selectedSearchResult.rnc,
          email: selectedSearchResult.email || "",
          phone: selectedSearchResult.phone || "",
          address: selectedSearchResult.location || ""
        })
      })

      const data = await response.json()

      if (data.success) {
        toast({
          title: "Cliente guardado",
          description: "El cliente ha sido guardado exitosamente",
        })
        // Refresh the page to update the customers list
        router.refresh()
      } else {
        toast({
          title: "Error al guardar",
          description: data.error || "No se pudo guardar el cliente",
          variant: "destructive",
        })
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al guardar el cliente",
        variant: "destructive",
      })
    } finally {
      setIsSavingCustomer(false)
    }
  }

  const handleAddItem = () => {
    const product = products.find((p) => p.id === selectedProduct)
    if (!product) return

    if (quantity > product.stock) {
      toast({
        title: "Error",
        description: "No hay suficiente stock disponible",
        variant: "destructive",
      })
      return
    }

    const existingItem = items.find((item) => item.product_id === product.id)
    if (existingItem) {
      setItems(
        items.map((item) =>
          item.product_id === product.id
            ? {
                ...item,
                quantity: item.quantity + quantity,
                subtotal: Math.round((item.quantity + quantity) * item.unit_price * 100) / 100,
              }
            : item,
        ),
      )
    } else {
      setItems([
        ...items,
        {
          product_id: product.id,
          product_name: product.name,
          product_sku: product.sku,
          quantity,
          unit_price: product.price,
          subtotal: Math.round(quantity * product.price * 100) / 100,
        },
      ])
    }

    setSelectedProduct("")
    setQuantity(1)
  }

  const handleRemoveItem = (productId: string) => {
    setItems(items.filter((item) => item.product_id !== productId))
  }

  const subtotal = Math.round(items.reduce((sum, item) => sum + item.subtotal, 0) * 100) / 100
  const tax = Math.round((invoiceType === "VALOR_FISCAL" || invoiceType === "VALOR_GUBERNAMENTAL") ? (subtotal * 0.18 * 100) / 100 : 0) // Solo ITBIS para facturas fiscales y gubernamentales
  const total = Math.round((subtotal + tax) * 100) / 100
  const pendingAmount = total - paymentAmount

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)

    try {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) throw new Error("No autenticado")

      if (items.length === 0) {
        throw new Error("Debe agregar al menos un producto")
      }

      // Generate order number
      const orderNumber = `ORD-${Date.now()}`

      // Create order
      const { data: order, error: orderError } = await supabase
        .from("orders")
        .insert({
          order_number: orderNumber,
          customer_id: customerId || null,
          customer_name: customerName,
          customer_rnc: customerRnc || null,
          customer_email: customerEmail || null,
          customer_phone: customerPhone || null,
          status,
          invoice_type: invoiceType,
          subtotal,
          tax,
          discount: 0,
          total,
          total_paid: paymentAmount,
          pending_amount: pendingAmount,
          payment_status: paymentAmount > 0 ? (pendingAmount > 0 ? 'Parcial' : 'Completo') : 'Pendiente',
          notes: notes || null,
          created_by: user.id,
        })
        .select()
        .single()

      if (orderError) throw orderError

      // Create order items
      const { error: itemsError } = await supabase.from("order_items").insert(
        items.map((item) => ({
          order_id: order.id,
          product_id: item.product_id,
          product_name: item.product_name,
          product_sku: item.product_sku,
          quantity: item.quantity,
          unit_price: item.unit_price,
          subtotal: item.subtotal,
        })),
      )

      if (itemsError) throw itemsError

      // Create payment record if there's a payment amount
      if (paymentAmount > 0) {
        const { error: paymentError } = await supabase.from("order_payments").insert({
          order_id: order.id,
          amount: paymentAmount,
          payment_method: paymentMethod || "Efectivo",
          notes: "Pago inicial",
          created_by: user.id,
        })

        if (paymentError) throw paymentError
      }

      toast({
        title: "Orden creada",
        description: `La orden ${orderNumber} ha sido creada exitosamente`,
      })

      router.push("/dashboard/orders")
      router.refresh()
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Error al crear la orden",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="customer">Cliente</Label>
          <Select value={customerId} onValueChange={handleCustomerChange}>
            <SelectTrigger>
              <SelectValue placeholder="Seleccionar cliente" />
            </SelectTrigger>
            <SelectContent>
              {customers.map((customer) => (
                <SelectItem key={customer.id} value={customer.id}>
                  {customer.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="rncLookup">Buscar por RNC</Label>
          <div className="flex gap-2">
            <Input
              id="rncLookup"
              value={rncLookup}
              onChange={(e) => setRncLookup(e.target.value)}
              placeholder="000-0000000-0"
            />
            <Button type="button" onClick={handleRncLookup} disabled={isLookingUp}>
              <Search className="h-4 w-4" />
            </Button>
          </div>
        </div>

        <div className="space-y-2">
          <Label htmlFor="nameLookup">Buscar por Nombre</Label>
          <div className="flex gap-2">
            <Input
              id="nameLookup"
              value={nameLookup}
              onChange={(e) => setNameLookup(e.target.value)}
              placeholder="Nombre del contribuyente"
            />
            <Button type="button" onClick={handleNameLookup} disabled={isLookingUp}>
              <Search className="h-4 w-4" />
            </Button>
          </div>
        </div>

        <div className="space-y-2">
          <Label htmlFor="customerName">Nombre del Cliente</Label>
          <Input
            id="customerName"
            value={customerName}
            onChange={(e) => setCustomerName(e.target.value)}
            placeholder="Nombre del cliente"
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="customerRnc">RNC/Cédula</Label>
          <Input
            id="customerRnc"
            value={customerRnc}
            onChange={(e) => setCustomerRnc(e.target.value)}
            placeholder="RNC o Cédula"
          />
        </div>

        {selectedSearchResult && (
          <div className="col-span-2">
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Información del Contribuyente</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="font-medium">RNC:</span> {selectedSearchResult.rnc}
                  </div>
                  <div>
                    <span className="font-medium">Estado:</span> {selectedSearchResult.status}
                  </div>
                  <div className="col-span-2">
                    <span className="font-medium">Nombre:</span> {selectedSearchResult.social_reason}
                  </div>
                  <div className="col-span-2">
                    <span className="font-medium">Nombre Comercial:</span> {selectedSearchResult.commercial_name || 'N/A'}
                  </div>
                  <div className="col-span-2">
                    <span className="font-medium">Actividad Económica:</span> {selectedSearchResult.economic_activity || 'N/A'}
                  </div>
                  <div>
                    <span className="font-medium">Tipo de Pago:</span> {selectedSearchResult.payment_type}
                  </div>
                </div>
                <div className="flex gap-2 pt-2">
                  <Button 
                    type="button" 
                    size="sm" 
                    onClick={handleSaveCustomer}
                    disabled={isSavingCustomer}
                  >
                    <Save className="h-4 w-4 mr-2" />
                    {isSavingCustomer ? "Guardando..." : "Guardar Cliente"}
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        <div className="space-y-2">
          <Label htmlFor="customerEmail">Email</Label>
          <Input
            id="customerEmail"
            type="email"
            value={customerEmail}
            onChange={(e) => setCustomerEmail(e.target.value)}
            placeholder="Email del cliente"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="customerPhone">Teléfono</Label>
          <Input
            id="customerPhone"
            value={customerPhone}
            onChange={(e) => setCustomerPhone(e.target.value)}
            placeholder="Teléfono del cliente"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="status">Estado</Label>
          <Select value={status} onValueChange={(value) => setStatus(value as typeof status)}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="Pendiente">Pendiente</SelectItem>
              <SelectItem value="Asignada">Asignada</SelectItem>
              <SelectItem value="En Proceso">En Proceso</SelectItem>
              <SelectItem value="Completada">Completada</SelectItem>
              <SelectItem value="Facturada">Facturada</SelectItem>
              <SelectItem value="Cancelada">Cancelada</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="invoiceType">Tipo de Factura</Label>
          <Select value={invoiceType} onValueChange={(value) => setInvoiceType(value as typeof invoiceType)}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="BASICA">Básica</SelectItem>
              <SelectItem value="VALOR_FISCAL">Valor Fiscal</SelectItem>
              <SelectItem value="VALOR_GUBERNAMENTAL">Valor Gubernamental</SelectItem>
            </SelectContent>
          </Select>
          <p className="text-sm text-muted-foreground">
            Tipo de factura que se generará al convertir esta orden
          </p>
        </div>

        <div className="space-y-2">
          <Label htmlFor="paymentMethod">Método de Pago</Label>
          <Select value={paymentMethod} onValueChange={(value) => setPaymentMethod(value as typeof paymentMethod)}>
            <SelectTrigger>
              <SelectValue placeholder="Seleccionar método" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="Efectivo">Efectivo</SelectItem>
              <SelectItem value="Tarjeta">Tarjeta</SelectItem>
              <SelectItem value="Transferencia">Transferencia</SelectItem>
              <SelectItem value="Cheque">Cheque</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="paymentAmount">Monto del Abono</Label>
          <Input
            id="paymentAmount"
            type="number"
            min="0"
            step="0.01"
            value={paymentAmount}
            onChange={(e) => setPaymentAmount(parseFloat(e.target.value) || 0)}
            placeholder="0.00"
          />
          <p className="text-sm text-muted-foreground">
            Monto inicial pagado por el cliente
          </p>
        </div>
      </div>


      <div className="space-y-2">
        <Label htmlFor="notes">Notas</Label>
        <Textarea id="notes" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Notas adicionales" />
      </div>

      <div className="space-y-4">
        <h3 className="text-lg font-semibold">Productos</h3>

        <div className="flex gap-4">
          <div className="flex-1">
            <Select value={selectedProduct} onValueChange={setSelectedProduct}>
              <SelectTrigger>
                <SelectValue placeholder="Seleccionar producto" />
              </SelectTrigger>
              <SelectContent>
                {products.map((product) => (
                  <SelectItem key={product.id} value={product.id}>
                    {product.name} - RD$ {product.price.toLocaleString()} (Stock: {product.stock})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <Input
            type="number"
            min="1"
            value={quantity}
            onChange={(e) => setQuantity(Number.parseInt(e.target.value) || 1)}
            className="w-24"
            placeholder="Cant."
          />

          <Button type="button" onClick={handleAddItem} disabled={!selectedProduct}>
            <Plus className="h-4 w-4" />
          </Button>
        </div>

        {items.length > 0 && (
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Producto</TableHead>
                  <TableHead>SKU</TableHead>
                  <TableHead className="text-right">Cantidad</TableHead>
                  <TableHead className="text-right">Precio</TableHead>
                  <TableHead className="text-right">Subtotal</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((item) => (
                  <TableRow key={item.product_id}>
                    <TableCell>{item.product_name}</TableCell>
                    <TableCell>{item.product_sku}</TableCell>
                    <TableCell className="text-right">{item.quantity}</TableCell>
                    <TableCell className="text-right">RD$ {(item.unit_price || 0).toLocaleString()}</TableCell>
                    <TableCell className="text-right">RD$ {(item.subtotal || 0).toLocaleString()}</TableCell>
                    <TableCell className="text-right">
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => handleRemoveItem(item.product_id)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}

        <div className="flex justify-end">
          <div className="w-64 space-y-2">
            <div className="flex justify-between">
              <span>Subtotal:</span>
              <span className="font-medium">RD$ {subtotal.toLocaleString()}</span>
            </div>
            {(invoiceType === "VALOR_FISCAL" || invoiceType === "VALOR_GUBERNAMENTAL") && (
              <div className="flex justify-between">
                <span>ITBIS (18%):</span>
                <span className="font-medium">RD$ {tax.toLocaleString()}</span>
              </div>
            )}
            <div className="flex justify-between border-t pt-2">
              <span className="font-bold">Total:</span>
              <span className="font-bold">RD$ {total.toLocaleString()}</span>
            </div>
            <div className="flex justify-between">
              <span>Abono:</span>
              <span className="font-medium text-green-600">RD$ {paymentAmount.toLocaleString()}</span>
            </div>
            <div className="flex justify-between border-t pt-2">
              <span className="font-bold">Saldo Pendiente:</span>
              <span className={`font-bold ${pendingAmount > 0 ? 'text-red-600' : 'text-green-600'}`}>
                RD$ {pendingAmount.toLocaleString()}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-4">
        <Button type="button" variant="outline" onClick={() => router.back()}>
          Cancelar
        </Button>
        <Button type="submit" disabled={isLoading || items.length === 0}>
          {isLoading ? "Creando..." : "Crear Orden"}
        </Button>
      </div>
    </form>
  )
}
