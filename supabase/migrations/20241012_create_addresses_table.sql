-- Create addresses table for storing user delivery addresses
CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    label VARCHAR(100) DEFAULT 'المنزل',
    city VARCHAR(100) NOT NULL,
    street VARCHAR(200) NOT NULL,
    area VARCHAR(100),
    building_number VARCHAR(50),
    floor_number VARCHAR(50),
    apartment_number VARCHAR(50),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notes TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on client_id for faster queries
CREATE INDEX IF NOT EXISTS idx_addresses_client_id ON public.addresses(client_id);

-- Create index on is_default for faster default address lookup
CREATE INDEX IF NOT EXISTS idx_addresses_is_default ON public.addresses(client_id, is_default);

-- Enable Row Level Security
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own addresses
CREATE POLICY "Users can view their own addresses"
    ON public.addresses
    FOR SELECT
    USING (auth.uid() = client_id);

-- Policy: Users can insert their own addresses
CREATE POLICY "Users can insert their own addresses"
    ON public.addresses
    FOR INSERT
    WITH CHECK (auth.uid() = client_id);

-- Policy: Users can update their own addresses
CREATE POLICY "Users can update their own addresses"
    ON public.addresses
    FOR UPDATE
    USING (auth.uid() = client_id)
    WITH CHECK (auth.uid() = client_id);

-- Policy: Users can delete their own addresses
CREATE POLICY "Users can delete their own addresses"
    ON public.addresses
    FOR DELETE
    USING (auth.uid() = client_id);

-- Policy: Admins can view all addresses
CREATE POLICY "Admins can view all addresses"
    ON public.addresses
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- Policy: Captains can view addresses for their assigned orders
CREATE POLICY "Captains can view delivery addresses"
    ON public.addresses
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'captain'
        )
    );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_addresses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER trigger_update_addresses_updated_at
    BEFORE UPDATE ON public.addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_addresses_updated_at();

-- Function to ensure only one default address per user
CREATE OR REPLACE FUNCTION ensure_single_default_address()
RETURNS TRIGGER AS $$
BEGIN
    -- If the new/updated address is set as default
    IF NEW.is_default = TRUE THEN
        -- Set all other addresses for this user to not default
        UPDATE public.addresses
        SET is_default = FALSE
        WHERE client_id = NEW.client_id
        AND id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to ensure only one default address
CREATE TRIGGER trigger_ensure_single_default_address
    BEFORE INSERT OR UPDATE ON public.addresses
    FOR EACH ROW
    EXECUTE FUNCTION ensure_single_default_address();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.addresses TO authenticated;
GRANT SELECT ON public.addresses TO anon;

-- Comment on table
COMMENT ON TABLE public.addresses IS 'Stores user delivery addresses with location data';
