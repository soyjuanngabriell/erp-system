import { createClient } from "@/lib/supabase/server"
import { NextResponse } from "next/server"

export async function POST(request: Request) {
  try {
    const { order_id } = await request.json()

    if (!order_id) {
      return NextResponse.json({ 
        success: false, 
        error: "Order ID is required" 
      }, { status: 400 })
    }

    const supabase = await createClient()

    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return NextResponse.json({ 
        success: false, 
        error: "Unauthorized" 
      }, { status: 401 })
    }

    // Get order details
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("*")
      .eq("id", order_id)
      .single()

    if (orderError || !order) {
      return NextResponse.json({ 
        success: false, 
        error: "Order not found" 
      }, { status: 404 })
    }

    // Check if order can be completed
    if (order.status === "Facturada") {
      return NextResponse.json({ 
        success: false, 
        error: "Order is already invoiced" 
      }, { status: 400 })
    }

    if (order.status === "Cancelada") {
      return NextResponse.json({ 
        success: false, 
        error: "Cannot complete a cancelled order" 
      }, { status: 400 })
    }

    // Update order status to completed
    const { data: updatedOrder, error: updateError } = await supabase
      .from("orders")
      .update({
        status: "Completada",
        updated_at: new Date().toISOString(),
      })
      .eq("id", order_id)
      .select()
      .single()

    if (updateError) {
      console.error("[Complete Order] Error:", updateError)
      return NextResponse.json({ 
        success: false, 
        error: "Error al completar la orden" 
      }, { status: 500 })
    }

    // If order is fully paid, convert to invoice
    let invoiceId = null
    if (updatedOrder.pending_amount <= 0) {
      // Ensure invoice_type is passed as string
      const invoiceType = updatedOrder.invoice_type ? String(updatedOrder.invoice_type) : "BASICA"
      const { data: convertedInvoiceId, error: conversionError } = await supabase.rpc("convert_order_to_invoice", {
        p_order_id: order_id,
        p_invoice_type: invoiceType
      })

      if (conversionError) {
        console.error("[Convert to Invoice] Error:", conversionError)
        // Don't fail the completion, just log the error
      } else {
        invoiceId = convertedInvoiceId
      }
    }

    return NextResponse.json({
      success: true,
      data: {
        order: updatedOrder,
        invoice_id: invoiceId,
        converted_to_invoice: !!invoiceId
      }
    })
  } catch (error) {
    console.error("[Complete Order] Error:", error)
    return NextResponse.json(
      {
        success: false,
        error: "Error interno del servidor",
      },
      { status: 500 },
    )
  }
}
