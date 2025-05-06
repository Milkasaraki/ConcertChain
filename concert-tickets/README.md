
### 📘 README for `ConcertChain`

# 🎫 ConcertChain

**ConcertChain** is a decentralized smart contract protocol for managing the creation, sale, and refunding of concert tickets on the Stacks blockchain. It enables artists, event organizers, and attendees to interact transparently, fairly, and securely — all on-chain.

---

## 🚀 Features

- **Create Listings:** Organizers can list concerts with detailed descriptions, seat sections, and custom pricing models.
- **Dynamic Sale Types:** Supports `fixed-price`, `auction`, and `dynamic-pricing` modes.
- **Purchase Tickets:** Users can purchase tickets by specifying a seat section and paying STX.
- **Refund Logic:** Refunds are processed automatically based on seat availability and pricing logic.
- **Post-Sale Controls:** Listings can be closed, canceled, or updated with available seats after the sale ends.
- **Secure Payments:** Funds are transferred through Clarity’s secure `stx-transfer?` operations.

---

## 📦 Contract Details

- **Language:** Clarity
- **Network:** Stacks Blockchain
- **Maps:**
  - `listings`: Tracks each concert listing and metadata
  - `purchases`: Records each buyer's purchase per concert
- **Read-Only Functions:**
  - `get-listing`
  - `get-purchase`
  - `get-current-block-height`

---

## 🛠 Functions Overview

| Function | Access | Description |
|---------|--------|-------------|
| `create-listing` | Public | Organizer creates a new concert ticket listing |
| `purchase-ticket` | Public | Buyer purchases a ticket for a specific section |
| `cancel-listing` | Public | Organizer cancels an active listing and triggers refunds |
| `close-listing` | Public | Organizer or contract owner closes listing after event |
| `update-section-availability` | Public | Contract owner marks which sections were used |
| `claim-refund` | Public | Buyers claim a refund based on listing outcomes |

---

## 🧾 Error Codes

- `ERR-UNAUTHORIZED (u100)`
- `ERR-INVALID-DESCRIPTION (u120)`
- `ERR-INVALID-SECTION (u112)`
- `ERR-LISTING-EXPIRED (u113)`
- `ERR-INVALID-PRICE-AMOUNT (u121)`
- ... (and more — see contract for full list)

---

## 📈 Example Use Case

1. An event organizer uses `create-listing` to register a concert.
2. Fans use `purchase-ticket` to buy seats in specific sections.
3. After the concert, the organizer updates used sections via `update-section-availability`.
4. Fans whose sections were not used can claim their money back using `claim-refund`.

---

## 🔐 Security Considerations

- Only the contract owner can update post-listing availability.
- Purchases are tracked per user, per listing.
- Refund logic ensures buyers are compensated only if their section was unused.

---

## 🤝 Contributing

Feel free to fork the repository, suggest features, and submit pull requests. This project aims to bring transparency to event ticketing.
