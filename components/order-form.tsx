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
import { Plus, Trash2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

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

export function OrderForm({ products, customers }: OrderFormProps) {
  const router = useRouter()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)

  const [customerId, setCustomerId] = useState("")
  const [customerName, setCustomerName] = useState("")
  const [customerRnc, setCustomerRnc] = useState("")
  const [status, setStatus] = useState("Pendiente")
  const [paymentMethod, setPaymentMethod] = useState("")
  const [notes, setNotes] = useState("")
  const [items, setItems] = useState<OrderItem[]>([])

  const [selectedProduct, setSelectedProduct] = useState("")
  const [quantity, setQuantity] = useState(1)

  const handleCustomerChange = (value: string) => {
    setCustomerId(value)
    const customer = customers.find((c) => c.id === value)
    if (customer) {
      setCustomerName(customer.name)
      setCustomerRnc(customer.rnc_cedula || "")
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
                subtotal: (item.quantity + quantity) * item.unit_price,
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
          subtotal: quantity * product.price,
        },
      ])
    }

    setSelectedProduct("")
    setQuantity(1)
  }

  const handleRemoveItem = (productId: string) => {
    setItems(items.filter((item) => item.product_id !== productId))
  }

  const subtotal = items.reduce((sum, item) => sum + item.subtotal, 0)
  const tax = subtotal * 0.18 // 18% ITBIS
  const total = subtotal + tax

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
          status,
          subtotal,
          tax,
          discount: 0,
          total,
          payment_method: paymentMethod || null,
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

        <div className="space-y-2">
          <Label htmlFor="status">Estado</Label>
          <Select value={status} onValueChange={setStatus}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="Pendiente">Pendiente</SelectItem>
              <SelectItem value="En Proceso">En Proceso</SelectItem>
              <SelectItem value="Completado">Completado</SelectItem>
              <SelectItem value="Cancelado">Cancelado</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="paymentMethod">Método de Pago</Label>
          <Select value={paymentMethod} onValueChange={setPaymentMethod}>
            <SelectTrigger>
              <SelectValue placeholder="Seleccionar método" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="Efectivo">Efectivo</SelectItem>
              <SelectItem value="Tarjeta">Tarjeta</SelectItem>
              <SelectItem value="Transferencia">Transferencia</SelectItem>
            </SelectContent>
          </Select>
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
                    <TableCell className="text-right">RD$ {item.unit_price.toLocaleString()}</TableCell>
                    <TableCell className="text-right">RD$ {item.subtotal.toLocaleString()}</TableCell>
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
            <div className="flex justify-between">
              <span>ITBIS (18%):</span>
              <span className="font-medium">RD$ {tax.toLocaleString()}</span>
            </div>
            <div className="flex justify-between border-t pt-2">
              <span className="font-bold">Total:</span>
              <span className="font-bold">RD$ {total.toLocaleString()}</span>
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
