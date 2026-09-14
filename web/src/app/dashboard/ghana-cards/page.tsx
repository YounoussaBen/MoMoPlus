"use client";

import axios from "axios";
import { useCallback, useMemo, useRef, useState, type FormEvent, type ReactNode } from "react";
import { CreditCard, Power } from "lucide-react";
import { useCreateGhanaCard, useGhanaCardsList, useToggleGhanaCard } from "@/hooks/use-ghana-cards";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import { formatDate } from "@/lib/format";
import type { GhanaCardRecord } from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu } from "@/components/dashboard/table-action-menu";

const filters: FilterDefinition[] = [
  {
    label: "Status",
    key: "is_active",
    options: [
      { label: "Active", value: "true" },
      { label: "Inactive", value: "false" },
    ],
  },
];

const cardNumberPattern = /^GHA(?:[\s-]?\d){10}$/i;

function getErrorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const detail = error.response?.data?.detail;
    if (typeof detail === "string") return detail;

    const values = Object.values(error.response?.data ?? {}).flat();
    if (values.length > 0) return values.join(" ");
  }

  return error instanceof Error ? error.message : "Could not save this Ghana Card.";
}

const columns: Column<GhanaCardRecord>[] = [
  {
    key: "masked_card_number",
    label: "Ghana Card",
    primaryOnMobile: true,
    render: (_, row) => <span className="font-medium">{row.masked_card_number}</span>,
  },
  {
    key: "surname",
    label: "Cardholder",
    render: (_, row) => `${row.first_names} ${row.surname}`.trim(),
  },
  {
    key: "date_of_birth",
    label: "Date of birth",
    hideOnMobile: true,
    render: (_, row) => (row.date_of_birth ? formatDate(row.date_of_birth) : "—"),
  },
  {
    key: "sex",
    label: "Sex",
    hideOnMobile: true,
    render: (_, row) => row.sex || "—",
  },
  {
    key: "is_active",
    label: "Status",
    render: (_, row) => (
      <Badge variant={row.is_active ? "success" : "muted"}>
        {row.is_active ? "Active" : "Inactive"}
      </Badge>
    ),
  },
  {
    key: "created_at",
    label: "Added",
    hideOnMobile: true,
    render: (_, row) => formatDate(row.created_at),
  },
];

export default function GhanaCardsPage() {
  const formRef = useRef<HTMLFormElement>(null);
  const [cardNumber, setCardNumber] = useState("");
  const [firstNames, setFirstNames] = useState("");
  const [surname, setSurname] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");
  const [sex, setSex] = useState("");
  const [frontFile, setFrontFile] = useState<File | null>(null);
  const [backFile, setBackFile] = useState<File | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const {
    page,
    pageSize,
    search,
    activeFilters,
    setPage,
    setPageSize,
    setSearch,
    setFilter,
    clearFilters,
  } = useTableUrlState({ filterKeys: filters.map((filter) => filter.key) });
  const query = useGhanaCardsList({ page, pageSize, search, activeFilters });
  const createMutation = useCreateGhanaCard();
  const toggleMutation = useToggleGhanaCard();

  const queryInput = useMemo(
    () => ({ page, pageSize, search, activeFilters }),
    [activeFilters, page, pageSize, search],
  );

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFormError(null);
    setSuccessMessage(null);

    const normalizedCardNumber = cardNumber.trim().toUpperCase();
    if (!cardNumberPattern.test(normalizedCardNumber)) {
      setFormError("Enter a valid Ghana Card number, for example GHA-728430143-4.");
      return;
    }
    if (!firstNames.trim() || !surname.trim()) {
      setFormError("First names and surname are required.");
      return;
    }
    if (!frontFile || !backFile) {
      setFormError("Upload both the front and back Ghana Card images.");
      return;
    }

    try {
      await createMutation.mutateAsync({
        card_number: normalizedCardNumber,
        first_names: firstNames.trim(),
        surname: surname.trim(),
        date_of_birth: dateOfBirth || null,
        sex: sex.trim().toUpperCase(),
        card_front_id: "",
        card_back_id: "",
        frontFile,
        backFile,
      });
      setCardNumber("");
      setFirstNames("");
      setSurname("");
      setDateOfBirth("");
      setSex("");
      setFrontFile(null);
      setBackFile(null);
      formRef.current?.reset();
      setSuccessMessage("Ghana Card added to the verification registry.");
    } catch (error) {
      setFormError(getErrorMessage(error));
    }
  };

  const handleSearch = useCallback((value: string) => setSearch(value), [setSearch]);
  const handleFilterChange = useCallback(
    (key: string, value: string) => setFilter(key, value),
    [setFilter],
  );
  const handleClearFilters = useCallback(() => clearFilters(), [clearFilters]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-foreground text-2xl font-bold">Ghana Card Registry</h1>
        <p className="text-muted-foreground text-sm">
          Register Ghana Cards used for automatic onboarding verification.
        </p>
      </div>

      <Card className="border-border/60 bg-card/82 border backdrop-blur-xl">
        <CardHeader>
          <CardTitle>Add Ghana Card</CardTitle>
          <CardDescription>
            Record the card details and upload clear images of both sides. Only active records can
            approve a matching mobile submission automatically.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form ref={formRef} onSubmit={handleSubmit} className="space-y-5">
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <Field label="Ghana Card number" htmlFor="card-number">
                <Input
                  id="card-number"
                  value={cardNumber}
                  onChange={(event) => setCardNumber(event.target.value.toUpperCase())}
                  placeholder="GHA-728430143-4"
                  autoComplete="off"
                />
              </Field>
              <Field label="First names" htmlFor="first-names">
                <Input
                  id="first-names"
                  value={firstNames}
                  onChange={(event) => setFirstNames(event.target.value)}
                  placeholder="Ernestina Korkor"
                />
              </Field>
              <Field label="Surname" htmlFor="surname">
                <Input
                  id="surname"
                  value={surname}
                  onChange={(event) => setSurname(event.target.value)}
                  placeholder="Manortey"
                />
              </Field>
              <Field label="Date of birth" htmlFor="date-of-birth">
                <Input
                  id="date-of-birth"
                  type="date"
                  value={dateOfBirth}
                  onChange={(event) => setDateOfBirth(event.target.value)}
                />
              </Field>
              <Field label="Sex" htmlFor="sex">
                <Input
                  id="sex"
                  value={sex}
                  onChange={(event) => setSex(event.target.value.toUpperCase())}
                  placeholder="F"
                  maxLength={16}
                />
              </Field>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <FileField
                id="card-front"
                label="Front image"
                file={frontFile}
                onChange={setFrontFile}
              />
              <FileField id="card-back" label="Back image" file={backFile} onChange={setBackFile} />
            </div>

            {formError && <p className="text-destructive text-sm">{formError}</p>}
            {successMessage && <p className="text-success text-sm">{successMessage}</p>}

            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? "Uploading and saving…" : "Add Ghana Card"}
            </Button>
          </form>
        </CardContent>
      </Card>

      <FilterBar
        onSearch={handleSearch}
        searchValue={search}
        searchPlaceholder="Search by card number or cardholder name..."
        filters={filters}
        activeFilters={activeFilters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
      />

      <DataTable
        columns={columns}
        data={query.data?.results ?? []}
        isLoading={query.isLoading}
        currentPage={queryInput.page}
        totalItems={query.data?.count ?? 0}
        pageSize={queryInput.pageSize}
        onPageChange={setPage}
        onPageSizeChange={setPageSize}
        emptyState={{
          icon: CreditCard,
          title: "No Ghana Cards found",
          description: "Add a card or adjust your search and filters.",
        }}
        actions={(row) => (
          <TableActionMenu
            actions={[
              {
                label: row.is_active ? "Deactivate" : "Activate",
                icon: Power,
                destructive: row.is_active,
                disabled: toggleMutation.isPending,
                onSelect: () => toggleMutation.mutate({ id: row.id, isActive: !row.is_active }),
              },
            ]}
          />
        )}
      />
    </div>
  );
}

function Field({
  label,
  htmlFor,
  children,
}: {
  label: string;
  htmlFor: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={htmlFor}>{label}</Label>
      {children}
    </div>
  );
}

function FileField({
  id,
  label,
  file,
  onChange,
}: {
  id: string;
  label: string;
  file: File | null;
  onChange: (file: File | null) => void;
}) {
  return (
    <Field label={label} htmlFor={id}>
      <Input
        id={id}
        type="file"
        accept="image/*"
        onChange={(event) => onChange(event.target.files?.[0] ?? null)}
        className="h-auto cursor-pointer py-3"
      />
      <p className="text-muted-foreground truncate text-xs">{file?.name ?? "No image selected"}</p>
    </Field>
  );
}
