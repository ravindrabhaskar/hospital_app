"use client";

import { useEffect, useRef, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BadgeCheck, ImageUp, Plus, Save, Star, X } from "lucide-react";
import { api } from "@/lib/api";
import type { DoctorProfile, DoctorProfileUpdate } from "@/lib/api/types";
import { useToast } from "@/components/toast";
import { Badge, Button, Card, Field, Input, PageHeader, QueryView, Textarea, Toggle, cx } from "@/components/ui";

const PROFILE_KEY = ["doctor", "me", "profile"];
const QUICK_LANGUAGES: { code: string; label: string }[] = [
  { code: "en", label: "English" },
  { code: "hi", label: "Hindi" },
  { code: "te", label: "Telugu" },
  { code: "ta", label: "Tamil" },
  { code: "kn", label: "Kannada" },
  { code: "mr", label: "Marathi" },
  { code: "bn", label: "Bengali" },
];
const PHOTO_TYPES = ["image/jpeg", "image/png", "image/webp"];
const PHOTO_MAX = 5 * 1024 * 1024;

const fee = z.coerce
  .number({ invalid_type_error: "Enter an amount" })
  .int("Whole rupees only")
  .min(0, "Cannot be negative")
  .max(100000, "That looks too high");

const schema = z.object({
  bio: z.string().trim().max(2000, "At most 2000 characters"),
  languages: z.array(z.string().trim().min(1)).min(1, "Add at least one language"),
  qualifications: z.string().trim().min(2, "Qualifications are required").max(300, "At most 300 characters"),
  fees: z.object({ video: fee, audio: fee, chat: fee, inClinic: fee }),
  acceptingBookings: z.boolean(),
});
type FormValues = z.input<typeof schema>;
type ParsedValues = z.output<typeof schema>;

function toForm(p: DoctorProfile): FormValues {
  return {
    bio: p.bio ?? "",
    languages: p.languages ?? [],
    qualifications: p.qualifications ?? "",
    fees: { video: p.fees.video, audio: p.fees.audio, chat: p.fees.chat, inClinic: p.fees.inClinic },
    acceptingBookings: p.acceptingBookings,
  };
}

export default function ClinicianProfilePage() {
  const query = useQuery({ queryKey: PROFILE_KEY, queryFn: () => api.doctorSelf.profile() });
  return (
    <>
      <PageHeader title="My profile" description="What patients see on your public doctor page." />
      <QueryView query={query} loadingRows={5}>
        {(p) => (
          <div className="flex flex-col gap-5">
            <ProfileHeader profile={p} />
            <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
              <ProfileForm key={p.id} profile={p} />
              <PhotoCard profile={p} />
            </div>
          </div>
        )}
      </QueryView>
    </>
  );
}

function initials(name: string) {
  return name
    .replace(/^dr\.?\s+/i, "")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("");
}

function Avatar({ src, name, size = "md" }: { src: string | null; name: string; size?: "md" | "lg" }) {
  const cls = size === "lg" ? "size-32 text-3xl" : "size-16 text-xl";
  if (src)
    return (
      // eslint-disable-next-line @next/next/no-img-element -- absolute public media URL / local object URL
      <img src={src} alt={`Photo of ${name}`} className={cx(cls, "shrink-0 rounded-full border border-line object-cover")} />
    );
  return (
    <div aria-hidden className={cx(cls, "flex shrink-0 items-center justify-center rounded-full bg-mint-100 font-semibold text-primary-dark")}>
      {initials(name) || "?"}
    </div>
  );
}

function ProfileHeader({ profile: p }: { profile: DoctorProfile }) {
  return (
    <Card>
      <div className="flex flex-wrap items-center gap-4">
        <Avatar src={p.photoUrl} name={p.name} />
        <div className="min-w-0 flex-1">
          <h2 className="flex flex-wrap items-center gap-2 text-lg font-semibold">
            {p.name}
            {p.verified && (
              <Badge tone="green" icon={<BadgeCheck className="size-3" aria-hidden />}>
                Verified
              </Badge>
            )}
            {p.acceptingBookings ? <Badge tone="green">Accepting bookings</Badge> : <Badge tone="amber">Not accepting bookings</Badge>}
          </h2>
          <p className="text-sm text-ink-muted">{p.specialtyName || p.specialty}</p>
          <dl className="mt-2 flex flex-wrap gap-x-6 gap-y-1 text-[13px]">
            <div className="flex gap-1">
              <dt className="text-ink-muted">Registration no.</dt>
              <dd className="font-medium">{p.registrationNumber || "—"}</dd>
            </div>
            <div className="flex gap-1">
              <dt className="text-ink-muted">Experience</dt>
              <dd className="font-medium">{p.experienceYears} yrs</dd>
            </div>
            <div className="flex items-center gap-1">
              <dt className="text-ink-muted">Rating</dt>
              <dd className="flex items-center gap-1 font-medium">
                <Star className="size-3.5 fill-current text-peach-fg" aria-hidden />
                {p.ratingCount ? `${p.rating.toFixed(1)} (${p.ratingCount} reviews)` : "No ratings yet"}
              </dd>
            </div>
          </dl>
          <p className="mt-1 text-xs text-ink-muted">Name, specialty and registration number are managed by the operations team.</p>
        </div>
      </div>
    </Card>
  );
}

function ProfileForm({ profile }: { profile: DoctorProfile }) {
  const qc = useQueryClient();
  const toast = useToast();
  const form = useForm<FormValues, unknown, ParsedValues>({ resolver: zodResolver(schema), defaultValues: toForm(profile) });
  const { register, control, handleSubmit, formState, reset } = form;
  const errors = formState.errors;

  const save = useMutation({
    mutationFn: (input: DoctorProfileUpdate) => api.doctorSelf.updateProfile(input),
    onSuccess: (p) => {
      qc.setQueryData(PROFILE_KEY, p);
      void qc.invalidateQueries({ queryKey: PROFILE_KEY });
      reset(toForm(p));
      toast.success("Profile saved");
    },
    onError: (e) => toast.apiError(e, "Could not save your profile"),
  });

  const onSubmit = handleSubmit((v) =>
    save.mutate({ bio: v.bio, languages: v.languages, qualifications: v.qualifications, fees: v.fees, acceptingBookings: v.acceptingBookings }),
  );

  const feeFields: { key: keyof FormValues["fees"]; label: string }[] = [
    { key: "video", label: "Video" },
    { key: "audio", label: "Audio" },
    { key: "chat", label: "Chat" },
    { key: "inClinic", label: "In clinic" },
  ];

  return (
    <Card title="Profile details">
      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
        <Controller
          control={control}
          name="acceptingBookings"
          render={({ field }) => (
            <div className="flex items-start justify-between gap-4 rounded-xl border border-line p-3.5">
              <div>
                <p className="text-sm font-semibold">
                  Accepting new bookings
                </p>
                <p className="text-xs text-ink-muted">
                  When off, you are hidden from the public doctor list (/doctors) and patients cannot book new consultations. Existing
                  appointments are not affected.
                </p>
              </div>
              <Toggle checked={!!field.value} onChange={field.onChange} label="Accepting new bookings" />
            </div>
          )}
        />

        <Field label="Qualifications" required error={errors.qualifications?.message}>
          {(id, d) => (
            <Input id={id} aria-describedby={d} aria-invalid={!!errors.qualifications} placeholder="MBBS, MD (General Medicine)" {...register("qualifications")} />
          )}
        </Field>

        <Field label="Bio" error={errors.bio?.message} hint="A short introduction shown on your profile.">
          {(id, d) => <Textarea id={id} rows={5} aria-describedby={d} aria-invalid={!!errors.bio} {...register("bio")} />}
        </Field>

        <Controller
          control={control}
          name="languages"
          render={({ field, fieldState }) => (
            <LanguagesInput value={field.value ?? []} onChange={field.onChange} error={fieldState.error?.message} />
          )}
        />

        <fieldset>
          <legend className="mb-2 text-sm font-semibold">Consultation fees (₹)</legend>
          <div className="grid gap-3 sm:grid-cols-2 md:grid-cols-4">
            {feeFields.map((f) => {
              const err = errors.fees?.[f.key]?.message;
              return (
                <Field key={f.key} label={f.label} required error={err}>
                  {(id, d) => (
                    <Input
                      id={id}
                      type="number"
                      min={0}
                      step={1}
                      inputMode="numeric"
                      aria-describedby={d}
                      aria-invalid={!!err}
                      {...register(`fees.${f.key}`)}
                    />
                  )}
                </Field>
              );
            })}
          </div>
        </fieldset>

        <div className="flex flex-wrap justify-end gap-2">
          <Button variant="ghost" disabled={!formState.isDirty || save.isPending} onClick={() => reset(toForm(profile))}>
            Discard changes
          </Button>
          <Button type="submit" loading={save.isPending} disabled={!formState.isDirty} icon={<Save className="size-4" aria-hidden />}>
            Save profile
          </Button>
        </div>
      </form>
    </Card>
  );
}

function LanguagesInput({ value, onChange, error }: { value: string[]; onChange: (v: string[]) => void; error?: string }) {
  const [draft, setDraft] = useState("");
  const has = (x: string) => value.some((v) => v.toLowerCase() === x.toLowerCase());
  const addMany = (text: string) => {
    const parts = text
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    const next = [...value];
    for (const p of parts) if (!next.some((v) => v.toLowerCase() === p.toLowerCase())) next.push(p);
    onChange(next);
    setDraft("");
  };
  return (
    <div className="flex flex-col gap-2">
      <Field label="Languages" required error={error} hint="Type a language and press Enter or comma. Codes (en, hi) or names are accepted.">
        {(id, d) => (
          <div className="flex gap-2">
            <Input
              id={id}
              aria-describedby={d}
              aria-invalid={!!error}
              value={draft}
              onChange={(e) => {
                if (e.target.value.includes(",")) addMany(e.target.value);
                else setDraft(e.target.value);
              }}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  if (draft.trim()) addMany(draft);
                }
              }}
            />
            <Button variant="secondary" disabled={!draft.trim()} onClick={() => addMany(draft)}>
              Add
            </Button>
          </div>
        )}
      </Field>
      {value.length > 0 && (
        <ul className="flex flex-wrap gap-1.5" aria-label="Selected languages">
          {value.map((l) => (
            <li key={l}>
              <span className="inline-flex items-center gap-1 rounded-full border border-[#c4e6d7] bg-teal-bg py-0.5 pl-2.5 pr-1 text-xs font-medium text-primary-dark">
                {QUICK_LANGUAGES.find((q) => q.code === l)?.label ?? l}
                <button
                  type="button"
                  onClick={() => onChange(value.filter((v) => v !== l))}
                  aria-label={`Remove ${l}`}
                  className="rounded-full p-0.5 hover:bg-white"
                >
                  <X className="size-3" aria-hidden />
                </button>
              </span>
            </li>
          ))}
        </ul>
      )}
      <div className="flex flex-wrap items-center gap-1.5">
        <span className="text-xs text-ink-muted">Quick add:</span>
        {QUICK_LANGUAGES.filter((q) => !has(q.code)).map((q) => (
          <button
            key={q.code}
            type="button"
            onClick={() => onChange([...value, q.code])}
            className="inline-flex h-7 items-center gap-1 rounded-full border border-line bg-white px-2.5 text-xs hover:bg-mint-50"
            aria-label={`Add ${q.label}`}
          >
            <Plus className="size-3" aria-hidden />
            {q.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function PhotoCard({ profile }: { profile: DoctorProfile }) {
  const qc = useQueryClient();
  const toast = useToast();
  const inputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [error, setError] = useState<string | undefined>();
  const previewRef = useRef<string | null>(null);

  const setPreviewUrl = (url: string | null) => {
    if (previewRef.current) URL.revokeObjectURL(previewRef.current);
    previewRef.current = url;
    setPreview(url);
  };
  useEffect(
    () => () => {
      if (previewRef.current) URL.revokeObjectURL(previewRef.current);
      previewRef.current = null;
    },
    [],
  );

  const clear = () => {
    setFile(null);
    setPreviewUrl(null);
    if (inputRef.current) inputRef.current.value = "";
  };

  const upload = useMutation({
    mutationFn: (f: File) => api.media.uploadPhoto(f),
    onSuccess: () => {
      toast.success("Photo updated");
      clear();
      void qc.invalidateQueries({ queryKey: PROFILE_KEY });
    },
    onError: (e) => toast.apiError(e, "Could not upload the photo"),
  });

  const onPick = (f: File | undefined) => {
    setError(undefined);
    if (!f) return clear();
    if (!PHOTO_TYPES.includes(f.type)) {
      setError("Choose a JPG, PNG or WebP image.");
      return clear();
    }
    if (f.size > PHOTO_MAX) {
      setError("The image must be 5 MB or smaller.");
      return clear();
    }
    setFile(f);
    setPreviewUrl(URL.createObjectURL(f));
  };

  return (
    <Card title="Profile photo" subtitle="Shown publicly on your doctor page">
      <div className="flex flex-col items-center gap-4">
        <Avatar src={preview ?? profile.photoUrl} name={profile.name} size="lg" />
        {preview && <p className="text-xs text-ink-muted">Preview, not uploaded yet</p>}
        <Field label="Choose an image" error={error} hint="JPG, PNG or WebP, up to 5 MB." className="w-full">
          {(id, d) => (
            <input
              ref={inputRef}
              id={id}
              type="file"
              accept={PHOTO_TYPES.join(",")}
              aria-describedby={d}
              aria-invalid={!!error}
              onChange={(e) => onPick(e.target.files?.[0])}
              className="block w-full text-sm file:mr-3 file:rounded-full file:border-0 file:bg-mint-100 file:px-3.5 file:py-2 file:text-[13px] file:font-semibold file:text-primary-dark hover:file:bg-mint-50"
            />
          )}
        </Field>
        <div className="flex w-full flex-wrap justify-end gap-2">
          {file && (
            <Button variant="ghost" onClick={clear} disabled={upload.isPending}>
              Cancel
            </Button>
          )}
          <Button
            disabled={!file}
            loading={upload.isPending}
            onClick={() => file && upload.mutate(file)}
            icon={<ImageUp className="size-4" aria-hidden />}
          >
            Upload photo
          </Button>
        </div>
      </div>
    </Card>
  );
}
