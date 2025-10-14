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
import { useToast } from "@/hooks/use-toast"

interface Product {
  id: string
  name: string
  sku: string
  stock: number
}

interface StockMovementFormProps {
  products: Product[]
}

export function StockMovementForm({ products }: StockMovementFormProps) {
  const router = useRouter()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)

  const [productId, setProductId] = useState("")
  const [type, setType] = useState("entrada")
  const [quantity, setQuantity] = useState(1)
  const [reason, setReason] = useState("")

  const selectedProduct = products.find((p) => p.id === productId)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)

    try {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) throw new Error("No autenticado")

      // Calculate the quantity change based on type
      let quantityChange = quantity
      if (type === "salida") {
        quantityChange = -quantity
      }

      // Use the database function to update stock
      const { error } = await supabase.rpc("update_product_stock", {
        p_product_id: productId,
        p_quantity: quantityChange,
        p_type: type,
        p_reason: reason || null,
        p_reference_id: null,
        p_user_id: user.id,
      })

      if (error) throw error

      toast({
        title: "Movimiento registrado",
        description: "El movimiento de stock ha sido registrado exitosamente",
      })

      router.push("/dashboard/inventory/movements")
      router.refresh()
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Error al registrar el movimiento",
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
          <Label htmlFor="product">Producto</Label>
          <Select value={productId} onValueChange={setProductId} required>
            <SelectTrigger>
              <SelectValue placeholder="Seleccionar producto" />
            </SelectTrigger>
            <SelectContent>
              {products.map((product) => (
                <SelectItem key={product.id} value={product.id}>
                  {product.name} - {product.sku} (Stock: {product.stock})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="type">Tipo de Movimiento</Label>
          <Select value={type} onValueChange={setType} required>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="entrada">Entrada</SelectItem>
              <SelectItem value="salida">Salida</SelectItem>
              <SelectItem value="ajuste">Ajuste</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="quantity">Cantidad</Label>
          <Input
            id="quantity"
            type="number"
            min="1"
            value={quantity}
            onChange={(e) => setQuantity(Number.parseInt(e.target.value) || 1)}
            required
          />
        </div>

        {selectedProduct && (
          <div className="space-y-2">
            <Label>Stock Actual</Label>
            <div className="flex h-10 items-center rounded-md border border-input bg-muted px-3 text-sm">
              {selectedProduct.stock} unidades
            </div>
          </div>
        )}

        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="reason">Razón del Movimiento</Label>
          <Textarea
            id="reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Describe la razón del movimiento"
            rows={3}
          />
        </div>
      </div>

      {selectedProduct && (
        <div className="rounded-lg border bg-muted p-4">
          <p className="text-sm font-medium mb-2">Resumen del Movimiento</p>
          <div className="space-y-1 text-sm">
            <p>
              <span className="text-muted-foreground">Producto:</span> {selectedProduct.name}
            </p>
            <p>
              <span className="text-muted-foreground">Stock actual:</span> {selectedProduct.stock} unidades
            </p>
            <p>
              <span className="text-muted-foreground">Cambio:</span>{" "}
              {type === "entrada" ? "+" : type === "salida" ? "-" : "±"}
              {quantity} unidades
            </p>
            <p className="font-medium">
              <span className="text-muted-foreground">Stock resultante:</span>{" "}
              {type === "entrada"
                ? selectedProduct.stock + quantity
                : type === "salida"
                  ? selectedProduct.stock - quantity
                  : selectedProduct.stock + quantity}{" "}
              unidades
            </p>
          </div>
        </div>
      )}

      <div className="flex justify-end gap-4">
        <Button type="button" variant="outline" onClick={() => router.back()}>
          Cancelar
        </Button>
        <Button type="submit" disabled={isLoading || !productId}>
          {isLoading ? "Registrando..." : "Registrar Movimiento"}
        </Button>
      </div>
    </form>
  )
}
