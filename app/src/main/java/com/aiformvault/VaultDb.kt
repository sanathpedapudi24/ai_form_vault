package com.aiformvault

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Insert
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Transaction

/**
 * Room schema, database and row mapping for the vault (issue #12).
 *
 * Everything lives in this one file: the row types, the row ↔ VaultData mapping and the
 * `@Database` class. They were kept in separate files initially, but this KSP2 (Kotlin 2.2.20) build
 * failed with `[MissingType]: Element ... references a type that is not present` for entities that
 * lived in a different file than the database, so they are colocated here.
 *
 * The mapping functions hold no Android types (Context, Uri, Keystore) so the row conversion is
 * unit tested on the JVM; the Room annotations are compile-time only.
 */

/** One document, in the same list order it has in [VaultData] (carried by `pos`). */
@Entity(
    tableName = "documents",
    indices = [Index("ownerId"), Index("type")],
)
data class DocumentRow(
    @PrimaryKey val id: String,
    val type: String,
    val category: String,
    val title: String,
    val ownerId: String,
    val pages: Int,
    val note: String,
    val createdAt: Long,
    val pos: Int,
) {
    fun toDocument(): Document = Document(
        id = id, type = DocType.valueOf(type), category = Category.valueOf(category), title = title,
        ownerId = ownerId, facts = emptyList(), pages = pages, note = note, createdAt = createdAt,
    )
}

/** A single fact within a document; the pair (documentId, key) is the primary key, `pos` preserves order. */
@Entity(
    tableName = "facts",
    primaryKeys = ["documentId", "key"],
    foreignKeys = [ForeignKey(
        entity = DocumentRow::class,
        parentColumns = ["id"],
        childColumns = ["documentId"],
        onDelete = ForeignKey.CASCADE,
    )],
)
data class FactRow(
    val documentId: String,
    val key: String,
    val value: String,
    val pos: Int,
)

/** A person (the user plus family members discovered from documents). */
@Entity(
    tableName = "people",
    indices = [Index("relation")],
)
data class PersonRow(
    @PrimaryKey val id: String,
    val name: String,
    val relation: String,
    val confirmed: Boolean,
    val evidence: String,
    val pos: Int,
)

/** A value the user typed or corrected themselves; the key is unique so it is the primary key. */
@Entity(tableName = "manual_facts")
data class ManualRow(
    @PrimaryKey val key: String,
    val value: String,
    val savedAt: Long,
)

/** Small scalar key/value rows (currently the count of fields the user has filled in). */
@Entity(tableName = "meta")
data class MetaRow(
    @PrimaryKey val k: String,
    val v: String,
)

/** Everything read out of the database in one go; feeds back into the in-memory VaultData. */
data class VaultRows(
    val documents: List<DocumentRow> = emptyList(),
    val facts: List<FactRow> = emptyList(),
    val people: List<PersonRow> = emptyList(),
    val manual: List<ManualRow> = emptyList(),
    val fieldsFilled: Int = 0,
) {
    fun toVault(): VaultData = VaultData(
        documents = documents.map { d ->
            d.toDocument().copy(facts = factsFor(d.id).map { Fact(FactKey.valueOf(it.key), it.value) })
        },
        people = people.map { Person(it.id, it.name, Relation.valueOf(it.relation), it.confirmed, it.evidence) },
        manual = manual.map { ManualFact(FactKey.valueOf(it.key), it.value, it.savedAt) },
        fieldsFilled = fieldsFilled,
    )

    private fun factsFor(docId: String): List<FactRow> = facts.filter { it.documentId == docId }.sortedBy { it.pos }
}

/** Maps the in-memory vault onto the database rows: list order is preserved through `pos`. */
fun VaultData.toRows(): VaultRows = VaultRows(
    documents = documents.mapIndexed { i, d -> DocumentRow(d.id, d.type.name, d.category.name, d.title, d.ownerId, d.pages, d.note, d.createdAt, i) },
    facts = documents.flatMap { d -> d.facts.mapIndexed { j, f -> FactRow(d.id, f.key.name, f.value, j) } },
    people = people.mapIndexed { i, p -> PersonRow(p.id, p.name, p.relation.name, p.confirmed, p.evidence, i) },
    manual = manual.map { ManualRow(it.key.name, it.value, it.savedAt) },
    fieldsFilled = fieldsFilled,
)

@Database(
    entities = [
        DocumentRow::class,
        FactRow::class,
        PersonRow::class,
        ManualRow::class,
        MetaRow::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class VaultDb : RoomDatabase() {
    abstract fun dao(): VaultDao

    companion object {
        const val NAME = "vault.db"

        fun open(ctx: Context, passphrase: ByteArray): VaultDb =
            Room.databaseBuilder(ctx, VaultDb::class.java, NAME)
                .openHelperFactory(net.zetetic.database.sqlcipher.SupportOpenHelperFactory(passphrase))
                .allowMainThreadQueries()
                .build()
    }
}

@Dao
interface VaultDao {
    /**
     * Full replace in one transaction: documents plus their facts, people, manual facts and the
     * scalar rows. With the foreign key cascade, dropping the documents drops their facts with them.
     * Small on purpose: a vault is one screenful of rows, and an atomic replace means a crash mid-write
     * can never leave a half-open database.
     */
    @Transaction
    fun replaceAll(rows: VaultRows) {
        clearDocuments()
        if (rows.documents.isNotEmpty()) insertDocuments(rows.documents)
        if (rows.facts.isNotEmpty()) insertFacts(rows.facts)
        if (rows.people.isNotEmpty()) insertPeople(rows.people)
        if (rows.manual.isNotEmpty()) insertManual(rows.manual)
        insertMeta(listOf(MetaRow("fieldsFilled", rows.fieldsFilled.toString())))
    }

    @Insert
    fun insertDocuments(rows: List<DocumentRow>)

    @Insert
    fun insertFacts(rows: List<FactRow>)

    @Insert
    fun insertPeople(rows: List<PersonRow>)

    @Insert
    fun insertManual(rows: List<ManualRow>)

    @Insert
    fun insertMeta(rows: List<MetaRow>)

    @Query("DELETE FROM documents")
    fun clearDocuments()

    @Query("DELETE FROM facts")
    fun clearFacts()

    @Query("SELECT * FROM documents ORDER BY pos")
    fun documents(): List<DocumentRow>

    @Query("SELECT * FROM facts ORDER BY documentId, pos")
    fun facts(): List<FactRow>

    @Query("SELECT * FROM people ORDER BY pos")
    fun people(): List<PersonRow>

    @Query("SELECT * FROM manual_facts")
    fun manualFacts(): List<ManualRow>

    @Query("SELECT * FROM meta WHERE k = 'fieldsFilled'")
    fun fieldsFilled(): List<MetaRow>
}
