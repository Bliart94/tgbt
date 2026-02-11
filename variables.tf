variable ami {
    description = "L'AMI à utiliser"
}

variable name {
    description = "Nom de la VM"
    type        = string
}

variable az {
    description = "Availibility zone à utiliser"
    type        = string
}

variable subnet_id {
    description = "Sous-réseau à utiliser"
    type        = string
}

variable disks {
    description = "Disques à ajouter à la VM"
    type        = map(any)
    default     = {}
}

variable workspace {
    description = "Terraform workspace"
    type        = string
}

variable identifiant {
    description = "tbgt"
    type        = string
    default     = "tbgt"
}
