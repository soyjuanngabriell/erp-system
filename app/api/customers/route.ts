import { createClient } from "@/lib/supabase/server"
import { NextResponse } from "next/server"

export async function POST(request: Request) {
  try {
    const { name, rnc_cedula, email, phone, address } = await request.json()

    if (!name) {
      return NextResponse.json({ 
        success: false, 
        error: "Name is required" 
      }, { status: 400 })
    }

    const supabase = await createClient()

    // Check if customer already exists with this RNC/Cédula
    if (rnc_cedula) {
      const { data: existingCustomer } = await supabase
        .from("customers")
        .select("id")
        .eq("rnc_cedula", rnc_cedula)
        .single()

      if (existingCustomer) {
        return NextResponse.json({ 
          success: false, 
          error: "Ya existe un cliente con este RNC/Cédula" 
        }, { status: 409 })
      }
    }

    // Insert new customer
    const { data: newCustomer, error } = await supabase
      .from("customers")
      .insert({
        name,
        rnc_cedula,
        email,
        phone,
        address
      })
      .select()
      .single()

    if (error) {
      console.error("[Save Customer] Error:", error)
      return NextResponse.json({ 
        success: false, 
        error: "Error al guardar el cliente" 
      }, { status: 500 })
    }

    return NextResponse.json({
      success: true,
      data: newCustomer
    })
  } catch (error) {
    console.error("[Save Customer] Error:", error)
    return NextResponse.json(
      {
        success: false,
        error: "Error interno del servidor",
      },
      { status: 500 },
    )
  }
}
